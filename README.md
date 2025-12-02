# UART Communication System in Verilog HDL
A fully functional and simulation-verified **Universal Asynchronous Receiver/Transmitter (UART)** communication system designed using **Verilog HDL**.  
This project was developed as part of the **Digital System Design** course at **Sukkur IBA University**.

## 📌 Project Overview

This project implements a complete **UART Communication System** consisting of:

- **UART Transmitter (TX)**
- **UART Receiver (RX)**
- **Baud Rate Generator**
- **UART Top Module**
- **Self-checking Testbench**

The architecture uses **Finite State Machines (FSMs)** to ensure deterministic and robust serial communication without requiring a shared clock signal.

## 🚀 Key Features

- **Full-Duplex Communication**
- **FSM-Based Design**
- **8-N-1 UART Format**
- **Framing Error Detection**
- **Configurable Baud Rate (Default: 9600 bps)**
- **Supports 1× and 16× Oversampling**
- **FPGA Compatible (Artix-7, Basys 3)**

## 🛠️ Technical Specifications

| Parameter     | Value     | Description |
|---------------|-----------|-------------|
| System Clock  | 50 MHz    | FPGA clock |
| Baud Rate     | 9600 bps  | Serial data rate |
| Data Width    | 8 bits    | Byte format |
| Oversampling  | 1× / 16×  | Timing accuracy |
| FPGA Target   | Artix-7   | xc7a12ticsg325-1L |

## 📂 Directory Structure

```
├── src/
│   ├── baud_rate_gen.v
│   ├── uart_tx.v
│   ├── uart_rx.v
│   └── uart_top.v
├── sim/
│   └── uart_tb.v
├── docs/
│   ├── UART_FSM_Diagrams.png
│   └── Project_Report.pdf
└── README.md
```

## 📐 Module Details

### 1. Baud Rate Generator
Generates timing pulses required for UART communication.

### 2. Transmitter (uart_tx.v)

FSM States:
- IDLE
- START
- DATA
- STOP

### 3. Receiver (uart_rx.v)

FSM States:
- IDLE
- START_DETECT
- DATA_RECEIVE
- STOP_CHECK

## 💻 Simulation & Verification

Test cases include:
- Normal transmission
- Back-to-back data
- Framing error injection

## 🔮 Future Scope

- Parity bit support
- FIFO buffering
- Hardware deployment on FPGA

## 👥 Authors

- **Muhammad Ahsan Kareem (133-22-0022)**
- **Sibgha Mursaleen (133-22-0018)**

Instructor: **Dr.-Engr. Kashif Hussain**
