/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

#include "ringbuffer.h"
#include "adf4351.h"


/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
SPI_HandleTypeDef hspi1;

UART_HandleTypeDef huart2;

/* USER CODE BEGIN PV */
ringbuf_uint8t uart2_rx_rb;
uint8_t uart2_tmp_rx_char;
#define uart2_rx_buffer_size 6
uint8_t uart2_rx_buffer[uart2_rx_buffer_size];

// Auto frequency hopping variables
uint32_t freq_hop_timer = 0;
uint8_t freq_hop_enabled = 1;  // Set to 0 to disable auto hopping
uint8_t freq_index = 0;

// Define frequency list (in Hz)
const uint64_t frequency_list[] = {
//		 500000000ULL	// 500.0 MHz
		1000000000ULL,  // 1.000 GHz
//		1000100000ULL,  // 1.100 GHz
//		1000200000ULL,  // 1.000 GHz
//		1000300000ULL,  // 1.100 GHz
//		1000400000ULL,  // 1.000 GHz
//		1000500000ULL,  // 1.100 GHz
};
const uint8_t frequency_list_size = sizeof(frequency_list) / sizeof(frequency_list[0]);

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_SPI1_Init(void);
/* USER CODE BEGIN PFP */


/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */

/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_USART2_UART_Init();
  MX_SPI1_Init();
  /* USER CODE BEGIN 2 */

    HAL_GPIO_WritePin(SPI1_CSn_GPIO_Port, SPI1_CSn_Pin, 1);
    HAL_GPIO_WritePin(SPI1_LD_GPIO_Port, SPI1_LD_Pin, 1);

      rb_init(&uart2_rx_rb, uart2_rx_buffer, uart2_rx_buffer_size);
      cmd_sm_init();
      send_ident();
      // enable receive interrupt for UART1
        HAL_UART_Receive_IT(&huart2, &uart2_tmp_rx_char, 1 );

  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */
        int loop_counter = 0;

  while (1)
  {
	  	  cmd_sm_update();

	  	  // Automatic frequency hopping every 2 seconds
	  	  if (freq_hop_enabled) {
	  	      if (HAL_GetTick() - freq_hop_timer >= 8000) {  // 2000 ms = 2 seconds
	  	          freq_hop_timer = HAL_GetTick();

	  	          // Set next frequency
	  	          adf4350_out_altvoltage0_frequency(frequency_list[freq_index]);

	  	          // Send notification via UART
	  	          char msg[50];
	  	          sprintf(msg, "\r\nFreq: %llu Hz\r\n", frequency_list[freq_index]);
	  	          HAL_UART_Transmit(&huart2, (uint8_t*)msg, strlen(msg), 1000);

	  	          // Move to next frequency
	  	          freq_index++;
	  	          if (freq_index >= frequency_list_size) {
	  	              freq_index = 0;  // Wrap around to start
	  	          }
	  	      }
	  	  }

//	  int data=0xFF;
	  	  		//main loop heart beat LED..
	  	  		if ( loop_counter == 100000 ) {
	  //	  			HAL_GPIO_TogglePin(LD2_GPIO_Port, LD2_Pin );
//	  	  			HAL_GPIO_TogglePin(SPI1_CSn_GPIO_Port, SPI1_CSn_Pin );
//
//	  	  			HAL_SPI_Transmit(&hspi1, &data, 1, 1000);
	  	  			loop_counter = 0;
	  	  		} else {
	  	  			++loop_counter;
	  	  		}


    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  }
  /* USER CODE END 3 */
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};
  RCC_PeriphCLKInitTypeDef PeriphClkInit = {0};

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI48;
  RCC_OscInitStruct.HSI48State = RCC_HSI48_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_NONE;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_HSI48;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_1) != HAL_OK)
  {
    Error_Handler();
  }
  PeriphClkInit.PeriphClockSelection = RCC_PERIPHCLK_USART2;
  PeriphClkInit.Usart2ClockSelection = RCC_USART2CLKSOURCE_PCLK1;
  if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInit) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_64;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 7;
  hspi1.Init.CRCLength = SPI_CRC_LENGTH_DATASIZE;
  hspi1.Init.NSSPMode = SPI_NSS_PULSE_DISABLE;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{

  /* USER CODE BEGIN USART2_Init 0 */

  /* USER CODE END USART2_Init 0 */

  /* USER CODE BEGIN USART2_Init 1 */

  /* USER CODE END USART2_Init 1 */
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 115200;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  huart2.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart2.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART2_Init 2 */

  /* USER CODE END USART2_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
/* USER CODE BEGIN MX_GPIO_Init_1 */
/* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOF_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOA, SPI1_CSn_Pin|SPI1_LD_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pins : SPI1_CSn_Pin SPI1_LD_Pin */
  GPIO_InitStruct.Pin = SPI1_CSn_Pin|SPI1_LD_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

/* USER CODE BEGIN MX_GPIO_Init_2 */
/* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */
// UART receive interrupt callback
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
  /* Prevent unused argument(s) compilation warning */
  //UNUSED(huart);
  // add received char to ring buffer.
  rb_put(&uart2_rx_rb, uart2_tmp_rx_char );
  // kick off the next read
  HAL_UART_Receive_IT(&huart2, &uart2_tmp_rx_char, 1 );
}

adf4350_init_param pll_config;

void cmd_sm_init() {
  // initialize pll_config structure
  pll_config.clkin = 25e6;
  pll_config.channel_spacing = 100000;
  pll_config.power_up_frequency = 75e6;
  pll_config.reference_div_factor = 1;
  pll_config.reference_doubler_enable = 0;
  pll_config.reference_div2_enable = 0;
  pll_config.phase_detector_polarity_positive_enable = 1;
  pll_config.lock_detect_precision_6ns_enable = 0; // 10 ns
  pll_config.lock_detect_function_integer_n_enable = 0; // Fractional pll
  pll_config.charge_pump_current = 7; //2.50
  pll_config.muxout_select = 6; // Digital Lock Detect Out
  pll_config.low_spur_mode_enable = 1; // higher noise, lower spurs.
  pll_config.cycle_slip_reduction_enable = 0;
  pll_config.charge_cancellation_enable = 0;
  pll_config.anti_backlash_3ns_enable = 0;
  pll_config.band_select_clock_mode_high_enable = 0; // low
  pll_config.clk_divider_12bit = 0;
  pll_config.clk_divider_mode = 0;
  pll_config.aux_output_enable = 0;
  pll_config.aux_output_fundamental_enable = 0;
  pll_config.mute_till_lock_enable = 0;
  pll_config.output_power = 3; // +2 dBm
  pll_config.aux_output_power = 0;
  adf4350_out_altvoltage0_powerdown(0); // power down PLL
  adf4350_setup(pll_config);
}

// temp storage for received number.
char cmdbuffer[15];
int cmdbuf_idx = 0;

// A simple atoi() function
int64_t numvec_atoi(char *str)
{
    int64_t res = 0; // Initialize result
    // Iterate through all characters of input string and
    // update result
    for (int i = 0; (str[i] != '\0') && (i < 16); ++i)
        res = res*10 + str[i] - '0';
    // return result.
    return res;
}

int isNumber(uint8_t c) {
	if (( c >= 0x30 ) && (c <= 0x39 )) {
		return 1;
	} else {
		return 0;
	}
}

void send_error_response() {
	// send ?; chars as error indicator..
	HAL_UART_Transmit(&huart2, (uint8_t*)"?;", 2, 100);
}

void send_accept_response() {
	// send k; chars as error indicator..
	HAL_UART_Transmit(&huart2, (uint8_t*)"k;", 2, 100);
}

char ident_string[] = "ADF4351 PLL Controller v1 (Auto-hop enabled);";

void send_ident() {
	HAL_UART_Transmit(&huart2, (uint8_t*)ident_string, sizeof(ident_string)-1, 1000);
}

void process_command() {
	uint64_t freq_hz=150e6;
	if ( cmdbuf_idx == 0 ) {
		// empty command buffer means no-op
		return;
	}
	switch(cmdbuffer[0]) {
	case 'f':
		// process freq set command
		freq_hz = numvec_atoi(&cmdbuffer[1]);
		adf4350_out_altvoltage0_frequency( freq_hz );
		send_accept_response();
		break;
	case 'n':
		// active no-op command
		send_accept_response();
		break;
	case 'i':
		// ident command
		send_ident();
		break;
	case 'd':
		// power down PLL
		adf4350_out_altvoltage0_powerdown(1); // power down PLL
		send_accept_response();
		break;
	case 'u':
		// power up PLL
		adf4350_out_altvoltage0_powerdown(0); // power up PLL
		send_accept_response();
		break;
	case 'a':
		// enable auto frequency hopping
		freq_hop_enabled = 1;
		freq_hop_timer = HAL_GetTick();  // Reset timer
		HAL_UART_Transmit(&huart2, (uint8_t*)"Auto-hop ON;", 12, 100);
		break;
	case 's':
		// disable (stop) auto frequency hopping
		freq_hop_enabled = 0;
		HAL_UART_Transmit(&huart2, (uint8_t*)"Auto-hop OFF;", 13, 100);
		break;
	default:
		// return error
		send_error_response();
	}
}

void cmd_sm_update() {
  // see if there is any chars to be processed..
  if ( rb_isempty(&uart2_rx_rb) == 0 ) {
	uint8_t byte_in='?';
	// get a byte from rx ring buffer.
	rb_get(&uart2_rx_rb, &byte_in);
	// echo char being processed
	HAL_UART_Transmit(&huart2, &byte_in, 1, 100);
    if ( cmdbuf_idx > 20 ) {
	  cmdbuf_idx = 0; // reset buffer
	  send_error_response();
	} else {
	  if ( byte_in != ';') {
		if ( (cmdbuf_idx==0 ) && (isNumber(byte_in)==1) ) {
			// error state, commands do not start with numbers.
			send_error_response();
		}
	    // add byte to cmd buffer
		cmdbuffer[cmdbuf_idx] = byte_in;
		cmdbuf_idx++;
	  } else {
	    // byte_in = ';' end of command
		// add null to end
		cmdbuffer[cmdbuf_idx] = 0;
		process_command();
		cmdbuf_idx=0;
	  }
	}
  }
}

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}

#ifdef  USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
