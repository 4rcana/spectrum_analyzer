#include "xaxidma.h"
#include "xparameters.h"
#include "xuartps.h"
#include "xil_cache.h"
#include "sleep.h"
#include <math.h>
#include <stdint.h>

#ifndef DMA_DEV_ID
  #ifdef XPAR_AXIDMA_0_DEVICE_ID
    #define DMA_DEV_ID XPAR_AXIDMA_0_DEVICE_ID
  #else
    #define DMA_DEV_ID 0
  #endif
#endif

#define UART_DEVICE_ID 0
#define FFT_SIZE      1024
#define RX_BYTES      (FFT_SIZE * 4) 

static XAxiDma AxiDma;

static XUartPs Uart_PS;

static uint32_t RxBuf[FFT_SIZE] __attribute__((aligned(32)));

static void print_s2mm_status(void)
{
    uint32_t sr = XAxiDma_ReadReg(AxiDma.RegBase,
                                  XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
    uint32_t cr = XAxiDma_ReadReg(AxiDma.RegBase,
                                  XAXIDMA_RX_OFFSET + XAXIDMA_CR_OFFSET);

    xil_printf("S2MM_DMACR=0x%08X  S2MM_DMASR=0x%08X\r\n", cr, sr);

    if (sr & XAXIDMA_HALTED_MASK) xil_printf("  - HALTED\r\n");
    if (sr & XAXIDMA_IDLE_MASK)   xil_printf("  - IDLE\r\n");
    if (sr & XAXIDMA_ERR_ALL_MASK) {
        xil_printf("  - ERROR bits set (0x%08X)\r\n", (sr & XAXIDMA_ERR_ALL_MASK));
    }
    if (sr & XAXIDMA_IRQ_IOC_MASK) xil_printf("  - IOC\r\n");
    if (sr & XAXIDMA_IRQ_DELAY_MASK) xil_printf("  - DELAY\r\n");
    if (sr & XAXIDMA_IRQ_ERROR_MASK) xil_printf("  - IRQ_ERROR\r\n");
}

static int dma_init(void)
{
    XAxiDma_Config *cfg = XAxiDma_LookupConfig(DMA_DEV_ID);
    if (!cfg) return XST_FAILURE;

    int status = XAxiDma_CfgInitialize(&AxiDma, cfg);
    if (status != XST_SUCCESS) return status;

    if (XAxiDma_HasSg(&AxiDma)) {
        xil_printf("ERROR: DMA is in SG mode; this test expects Simple mode.\r\n");
        return XST_FAILURE;
    }

    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    XAxiDma_Reset(&AxiDma);
    while (!XAxiDma_ResetIsDone(&AxiDma)) {}

    return XST_SUCCESS;
}

static int dma_capture_one_frame(void)
{
    Xil_DCacheFlushRange((UINTPTR)RxBuf, RX_BYTES);

    int status = XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)RxBuf, RX_BYTES,
                                       XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) return status;

    int timeout = 20000000;
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DEVICE_TO_DMA) && --timeout) {}

    if (timeout == 0) {
        xil_printf("TIMEOUT waiting for S2MM\r\n");
        print_s2mm_status();
        return XST_FAILURE;
    }

    uint32_t sr = XAxiDma_ReadReg(AxiDma.RegBase,
                                  XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
    if (sr & XAXIDMA_ERR_ALL_MASK) {
        xil_printf("S2MM ERROR, SR=0x%08X\r\n", sr);
        XAxiDma_Reset(&AxiDma);
        while (!XAxiDma_ResetIsDone(&AxiDma)) {}
        return XST_FAILURE;
    }

    Xil_DCacheInvalidateRange((UINTPTR)RxBuf, RX_BYTES);

    return XST_SUCCESS;
}

static void decode_word(uint32_t w, int16_t *re, int16_t *im)
{
    *im = (int16_t)(w >> 16);
    *re = (int16_t)(w & 0xFFFF);
}

static int uart_init()
{
    XUartPs_Config *Config;
    int Status;
    Config = XUartPs_LookupConfig(UART_DEVICE_ID);
    if (NULL == Config) {
        return XST_FAILURE;
    }
    
    Status = XUartPs_CfgInitialize(&Uart_PS, Config, Config->BaseAddress);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }
    XUartPs_SetBaudRate(&Uart_PS, 921600);
    return 0;
}

void data_to_terminal()
{
    float mag[FFT_SIZE];
    float peak_mag = 0;
    int peak_mag_index = 0;

    for (int i = 0; i < FFT_SIZE; i++) {
        int16_t re, im;
        decode_word(RxBuf[i], &re, &im);
        mag[i] = sqrtf(re*re+im*im);
        if (mag[i] > peak_mag) { peak_mag = mag[i]; peak_mag_index = i; }
        xil_printf("i: %d, re: %d, im: %d\r\n", i, re, im);
    }

    int whole = (int)peak_mag;
    int frac = (int)((peak_mag - whole) * 100);

    xil_printf("index: %d peak_mag: %d.%02d \r\n", peak_mag_index, whole, frac);
}

void data_to_python()
{
    float magnitude;
    int whole;
    int frac;
    
    for (int i = 0; i < FFT_SIZE; i++) {
        int16_t re, im;
        decode_word(RxBuf[i], &re, &im);
        magnitude = sqrtf(re*re+im*im);
        whole = (int)magnitude;
        frac = (int)((magnitude - whole) * 100);
        xil_printf("%d,%d.%02d\n", i, whole, frac);
    }
}

int main(void)
{
    uart_init();
    char *msg = "Hello from Zynq PS!\r\n";
    XUartPs_Send(&Uart_PS, (u8*)msg, strlen(msg));

    if (dma_init() != XST_SUCCESS) {
        char *msg = "DMA init failed\r\n";
        XUartPs_Send(&Uart_PS, (u8*)msg, strlen(msg));
        while (1) {}
    }
    xil_printf("DMA ready.\r\n");

    for (int frame = 1; ; frame++) {
        int status = dma_capture_one_frame();
        if (status != XST_SUCCESS) {
            xil_printf("Capture failed\r\n");
            usleep(200000);
            continue;
        }
        //data_to_terminal();
        data_to_python();
        
    }

    return 0;
}