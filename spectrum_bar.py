from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import numpy as np
import tkinter as tk
import tkinter.ttk as ttk
import serial as sr
import serial.tools.list_ports
import time

# Konstantos
DEFAULT_BAUDRATE = 921600
FFT_BINS = 1024
FREQ = 65000000

# Kintamieji
UART_Started = False # Apsauga, kad duomenys nebūtų nuskaitomi, kol COM PORT uždarytas
COM_Port_Selected = None
COM_Port = None

chart_x_data = np.linspace(-FREQ/2, FREQ/2, FFT_BINS)
#chart_x_data = np.arange(FFT_BINS) * (FREQ / FFT_BINS)
chart_y_data = np.zeros(FFT_BINS)

# Funkcijos
# COM PORT aptarnavimo funkcija
def Display_UART_Data():
    global COM_Port_Selected, UART_Started, chart_x_data, chart_y_data
    if UART_Started and COM_Port_Selected.in_waiting > 0:

        # --- Measure COM read time ---
        start_read = time.perf_counter()

        for i in range(FFT_BINS):
            try:
                decoded_data = COM_Port_Selected.readline().decode(errors="ignore").strip()
                idx, mag = decoded_data.split(',', 1)
                if(int(idx) < FFT_BINS // 2):
                    chart_y_data[FFT_BINS // 2 + int(idx)] = float(mag)
                else:
                    chart_y_data[int(idx) - FFT_BINS // 2] = float(mag)
            except (ValueError, IndexError):
                continue

        end_read = time.perf_counter()
        com_read_time = end_read - start_read

        # --- Measure chart update time ---
        start_draw = time.perf_counter()

        # Update the chart
        for bar, value in zip(Chart_Bar, chart_y_data):
            bar.set_height(value)

        # Force multiple refresh attempts
        Chart_Canvas.draw_idle()  # Schedule a draw
        Chart_Canvas.flush_events()  # Process any pending GUI events
        Chart_Canvas.draw()  # Force immediate draw

        end_draw = time.perf_counter()
        chart_update_time = end_draw - start_draw

        # --- Print timings ---
        print(f"COM read time: {com_read_time*1000:.2f} ms, Chart update time: {chart_update_time*1000:.2f} ms")


    # Iškviečiama ta pati funkcija iš naujo, sudaromas begalinis ciklas
    Application_window.after(1, Display_UART_Data)

# Atnaujina visus aktyvius COM PORT rodomus išskleidžiame sąraše `COM_Port_Selection`
def update_serial_port_values(event):
    COM_Port_Selection['values'] = serial.tools.list_ports.comports()

# COM PORT pasirinkimo funkcija
# Aktyvuojama pasirinkus COM PORT iš sąrašo
def Get_COM_Port(event):
    global COM_Port_Selected, COM_Port
    # Pasirinkto COM PORT numerio atrinkimas
    COM_Port_Full_Name = COM_Port_Selection.get().split()
    COM_Port = COM_Port_Full_Name[0]
    # Aktyvuojami COM PORT valdymo mygtukai
    Start_Stop_Button["state"] = "normal"
    Start_Stop_Button["text"] = "Atidaryti COM PORT"

# COM PORT atidarymo/uždarymo funkcija
# Aktyvuojama paspaudus `Start_Stop_Button` mygtuką
def Start_Stop_COM_Port():
    global UART_Started, COM_Port, COM_Port_Selected
    if UART_Started:
        # Sustabdyti COM PORT
        COM_Port_Selected.close()
        Start_Stop_Button["text"] = "Atidaryti COM PORT"
        UART_Started = False
    else:
        # Atidaryti COM PORT
        Baud_Rate = int(Baud_Rate_Selection.get())
        COM_Port_Selected = sr.Serial(COM_Port, Baud_Rate, timeout=1)
        COM_Port_Selected.close()
        COM_Port_Selected.open()
        Start_Stop_Button["text"] = "Uždaryti COM PORT"
        UART_Started = True

# Grafinės vartotojo sąsajos kūrimas
# Pagrindinės aplikacijos langas
Application_window = tk.Tk()
Application_window.title('Spectrum Bar')
Application_window.geometry("800x700")
for i in range(4, 5):
    Application_window.grid_rowconfigure(i, weight=1)
for i in range(5):
    Application_window.grid_columnconfigure(i, weight=1)

# COM PORT valdymo elementai
UART_Label = tk.Label(Application_window, text = "COM PORT Valdymas")
UART_COM_Port_Label = tk.Label(Application_window, text = "PORT pasirinkimas:")
UART_COM_Baud_Rate_Label = tk.Label(Application_window, text = "Baud Rate pasirinkimas:")
# COM PORT pasirinkimo sąrašo laukas
COM_Port_Selection = ttk.Combobox(Application_window, state='readonly')
COM_Port_Selection.set("Pasirinkti COM port")
COM_Port_Selection.bind('<Button-1>', update_serial_port_values)
Start_Stop_Button = tk.Button(Application_window, text = "Atidaryti COM PORT", command = lambda: Start_Stop_COM_Port(), state = "disabled")
available_ports = serial.tools.list_ports.comports()
if available_ports:
    COM_Port_Selection.set(available_ports[0])
    Get_COM_Port(None)
COM_Port_Selection.bind('<<ComboboxSelected>>', Get_COM_Port)

# COM PORT duomenų atvaizdavimo tekstinis laukelis
COM_Port_UART_Data_Display = tk.Text(Application_window, width=50, height=26, bg="light grey", state='disabled')
Clear_Button = tk.Button(Application_window, text = "Išvalyti duomenis",  command = lambda: Clear_All())

# Baud rate pasirinkimo sąrašo laukas
Baud_Rate_Selection = ttk.Combobox(Application_window, state='readonly')
Baud_Rate_Selection['values'] = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600, 3000000]
Baud_Rate_Selection.set(DEFAULT_BAUDRATE)

# Grafikas
Chart_Figure = Figure()
Chart_Plot = Chart_Figure.add_subplot(111)
Chart_Plot.set_title('Spektras')
Chart_Plot.set_xlabel('Dažnis, Hz')
Chart_Plot.set_ylabel('Amplitudė')
Chart_Plot.set_xlim(-FREQ/2, FREQ/2)
Chart_Plot.set_ylim(0, 200)
Chart_Plot.set_facecolor('#1a1a1a')
Chart_Plot.grid()
Chart_Bar = Chart_Plot.bar(chart_x_data, chart_y_data, width=(FREQ/FFT_BINS), color='yellow')
Chart_Canvas = FigureCanvasTkAgg(Chart_Figure, master=Application_window)


# Title / section label
UART_Label.grid(row=0, column=0, columnspan=4, pady=10, sticky="")  # center across 4 columns

# COM PORT selection
UART_COM_Port_Label.grid(row=1, column=0, columnspan=2, sticky="", pady=5)
COM_Port_Selection.grid(row=1, column=2, columnspan=2, sticky="", pady=5)

# Baud rate selection
UART_COM_Baud_Rate_Label.grid(row=2, column=0, columnspan=2, sticky="", pady=5)
Baud_Rate_Selection.grid(row=2, column=2, columnspan=2, sticky="", pady=5)

# Start / Stop button
Start_Stop_Button.grid(row=3, column=0, columnspan=4, pady=10, sticky="")  # centered across all columns

# Chart canvas
Chart_Canvas.get_tk_widget().grid(row=4, column=0, columnspan=4, padx=10, pady=10, sticky="nsew")

# Aplikacijos atidarymas ir pagrindinės funkcijos iškvietimas
Application_window.after(1,Display_UART_Data)
Application_window.mainloop()
