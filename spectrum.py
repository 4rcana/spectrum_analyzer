from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure
import numpy as np
import tkinter as tk
import tkinter.ttk as ttk
import serial as sr
import serial.tools.list_ports

# Konstantos
DEFAULT_BAUDRATE = 921600
FFT_BINS = 1024
RESOLUTION = 65000000 / FFT_BINS

# Kintamieji
UART_Started = False # Apsauga, kad duomenys nebūtų nuskaitomi, kol COM PORT uždarytas
COM_Port_Selected = None
COM_Port = None

chart_x_data = [i * RESOLUTION for i in range(FFT_BINS)]

# Funkcijos
# COM PORT aptarnavimo funkcija
def Display_UART_Data():
    global COM_Port_Selected, UART_Started, chart_x_data, chart_y_data
    if UART_Started and COM_Port_Selected.in_waiting > 0:
        # Nuskaitoma viena duomenų eilutė
        for i in range(FFT_BINS):
            COM_Port_Data = COM_Port_Selected.readline()
            decoded_data = COM_Port_Data.decode().strip()
            chart_y_data[i] = float(decoded_data) if decoded_data else 0.0

        print(chart_y_data)

        # Update the chart
        Chart_Line.set_data(chart_x_data, chart_y_data)
        Chart_Plot.set_xlim(0, max(chart_x_data))
        Chart_Plot.set_ylim(0, max(chart_y_data))
        Chart_Canvas.draw()

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
Application_window.title('Spektras')
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

# Baud rate pasirinkimo sąrašo laukas
Baud_Rate_Selection = ttk.Combobox(Application_window, state='readonly')
Baud_Rate_Selection['values'] = [9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600]
Baud_Rate_Selection.set(DEFAULT_BAUDRATE)

# Grafikas
Chart_Figure = Figure()
Chart_Plot = Chart_Figure.add_subplot(111)
Chart_Plot.set_title('Duomenų grafikas')
Chart_Plot.set_xlabel('Atskaitos, n')
Chart_Plot.set_ylabel('Amplitudė')
Chart_Plot.grid()
Chart_Line = Chart_Plot.plot([],[])[0]
Chart_Canvas = FigureCanvasTkAgg(Chart_Figure, master=Application_window)

# Grafinės vartotojo sąsajos elementų išdėstymas lentelės principu
UART_Label.grid(row=0, column=2, columnspan=2, padx=10, pady=10)
UART_COM_Port_Label.grid(row=1, column=2, padx=10, pady=10)
COM_Port_Selection.grid(row=1, column=3, padx=10, pady=10)
UART_COM_Baud_Rate_Label.grid(row=2, column=2, padx=10, pady=10)
Baud_Rate_Selection.grid(row=2, column=3, padx=10, pady=10)
Start_Stop_Button.grid(row=3, column=2, columnspan=2, padx=10, pady=10)

Chart_Canvas.get_tk_widget().grid(row=4, column=0, columnspan=5, padx=0, pady=10, sticky="nsew")

# Aplikacijos atidarymas ir pagrindinės funkcijos iškvietimas
Application_window.after(1,Display_UART_Data)
Application_window.mainloop()
