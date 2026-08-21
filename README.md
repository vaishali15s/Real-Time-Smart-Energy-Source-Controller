# ⚡ Real-Time Smart Energy Source Controller

A Verilog HDL-based smart home energy management system that dynamically selects between **Solar, Battery, and Grid power** according to load demand, solar availability, battery State of Charge (SOC), time-of-use tariff, and system fault conditions.

The project is designed as a **digital hardware control system** using a Finite State Machine (FSM), battery SOC management, load calculation, priority-based load control, fault protection, tariff-aware decision making, and simulation-based verification.

---

## 📌 Project Overview

In a conventional home energy system, appliances may continue using grid electricity even when renewable solar energy is available. This increases electricity costs and wastes available renewable energy.

This project implements a hardware-based energy source controller that continuously evaluates:

- Current appliance power demand
- Solar power generation
- Battery State of Charge (SOC)
- Time of day
- Electricity tariff
- System faults
- Maximum allowable load

Based on these parameters, the controller selects the most appropriate energy source:

**Solar → Battery → Grid**

while providing protection against overload, battery over-temperature, solar faults, and grid faults.

---

## 🎯 Objectives

- Reduce unnecessary grid electricity usage.
- Maximize utilization of available solar energy.
- Use battery storage when solar power is insufficient.
- Prevent excessive battery discharge.
- Consider electricity tariffs during source selection.
- Detect unsafe operating conditions.
- Disconnect loads during critical faults.
- Prevent rapid switching between energy sources using FSM hysteresis.
- Verify the complete control system through Verilog simulation.

---

## ✨ Key Features

### 🔋 1. Hybrid Energy Source Selection

The controller supports three primary energy sources:

| Source | Purpose |
|---|---|
| ☀️ Solar | Preferred renewable source when sufficient |
| 🔋 Battery | Backup/storage source when solar is insufficient |
| ⚡ Grid | Fallback source when solar and battery cannot satisfy demand |

The system also supports:

- `IDLE` mode when there is no load
- `FAULT` mode when an unsafe condition is detected

---

### 🧠 2. FSM-Based Energy Management

The core decision-making logic is implemented using a Finite State Machine.

The FSM contains five states:

```text
             ┌──────────────┐
             │    SOLAR     │
             └──────┬───────┘
                    │
                    ▼
             ┌──────────────┐
             │   BATTERY    │
             └──────┬───────┘
                    │
                    ▼
             ┌──────────────┐
             │     GRID     │
             └──────────────┘

      ┌──────────────┐
      │    FAULT     │
      └──────────────┘

      ┌──────────────┐
      │     IDLE     │
      └──────────────┘
    
FSM States
| State     | Encoding | Description                     |
| --------- | -------- | ------------------------------- |
| `SOLAR`   | `3'b000` | Solar supplies the load         |
| `BATTERY` | `3'b001` | Battery supplies the load       |
| `GRID`    | `3'b010` | Grid supplies the load          |
| `FAULT`   | `3'b011` | All energy sources are disabled |
| `IDLE`    | `3'b100` | No load demand                  |
The FSM ensures that only one primary energy source is active at a time.

🏗️ System Architecture
                   ┌─────────────────────┐
                   │  Appliance Inputs   │
                   │ AC / Fan / WM /     │
                   │ Fridge / Bulb       │
                   └──────────┬──────────┘
                              │
                              ▼
                   ┌─────────────────────┐
                   │   Load Calculator   │
                   └──────────┬──────────┘
                              │
                              ▼
        ┌────────────────────────────────────────┐
        │          ENERGY FSM CONTROLLER         │
        │                                        │
        │  • Solar availability                  │
        │  • Battery SOC                         │
        │  • Tariff                              │
        │  • Fault conditions                    │
        │  • Load demand                         │
        │  • Load prediction                     │
        │  • Hysteresis                          │
        └───────┬────────────┬────────────┬──────┘
                │            │            │
                ▼            ▼            ▼
             ☀️ SOLAR     🔋 BATTERY     ⚡ GRID
                │            │            │
                └────────────┼────────────┘
                             │
                             ▼
                   ┌─────────────────────┐
                   │ Appliance Supply    │
                   │ Control / Load      │
                   │ Management           │
                   └─────────────────────┘

                 ┌───────────────────────┐
                 │ Battery SOC Controller│
                 └───────────────────────┘

                 ┌───────────────────────┐
                 │ Fault Detection       │
                 └───────────────────────┘

🔌 Input Parameters
The top-level controller accepts the following inputs:
| Input                 | Width | Description                    |
| --------------------- | ----: | ------------------------------ |
| `clk`                 |     1 | System clock                   |
| `reset`               |     1 | Asynchronous reset             |
| `ac_on`               |     1 | Air conditioner request        |
| `fan_on`              |     1 | Fan request                    |
| `wm_on`               |     1 | Washing machine request        |
| `bulb_on`             |     1 | Bulb request                   |
| `fridge_on`           |     1 | Refrigerator request           |
| `day_flag`            |     1 | Indicates daytime              |
| `peak_evening_flag`   |     1 | Indicates peak tariff period   |
| `solar_generation`    |    16 | Current solar generation       |
| `battery_overtemp_in` |     1 | Battery over-temperature fault |
| `solar_fault_in`      |     1 | Solar system fault             |
| `overload_in`         |     1 | External overload indication   |
| `grid_fault_in`       |     1 | Grid availability fault        |

📤 Main Outputs
| Output            | Description                   |
| ----------------- | ----------------------------- |
| `solar_mode`      | Solar is the active source    |
| `battery_mode`    | Battery is the active source  |
| `grid_mode`       | Grid is the active source     |
| `fault_mode`      | System is in fault state      |
| `idle_mode`       | No load is present            |
| `fault_code`      | Encoded fault information     |
| `ac_supply`       | AC supply enable              |
| `fridge_supply`   | Refrigerator supply enable    |
| `wm_supply`       | Washing machine supply enable |
| `fan_supply`      | Fan supply enable             |
| `bulb_supply`     | Bulb supply enable            |
| `final_load`      | Actual served load            |
| `tariff_per_unit` | Current electricity tariff    |

⚙️ Load Calculation
The top-level module calculates the requested load by adding the nominal power of every active appliance.
Current nominal values:
| Appliance       |  Power |
| --------------- | -----: |
| Air Conditioner | 1500 W |
| Refrigerator    |  300 W |
| Washing Machine |  500 W |
| Fan             |   75 W |
| Bulb            |   20 W |
For example:
AC + Fan + Bulb
= 1500 + 75 + 20
= 1595 W
The resulting total_load is supplied to the FSM for energy-source selection.

🔋 Battery Management
Battery operation is controlled through battery_soc_controller.v.
The battery SOC is represented as a percentage from:
0% ─────────────────────── 100%

The battery initializes at:
SOC = 50%
Charging

The battery charges when:
allow_charge = 1
AND
(
    precharge_request = 1
    OR
    solar_generation > load
)
The default charging step is:
+2% SOC / clock cycle
SOC is capped at 100%.

Discharging
The battery discharges when:
battery_mode = 1
AND
load > 0
The default discharge step is:
-1% SOC / clock cycle
The battery SOC cannot fall below 0%.

Minimum Safe SOC
The controller uses:
SOC_LOW = 20%
When:
SOC <= 20%

the FSM prefers the grid rather than continuing battery discharge.
This prevents deep battery discharge in the digital model.

☀️ Solar Energy Management
Solar power is preferred whenever sufficient generation is available.
The fundamental decision is:
If solar >= load
        ↓
      SOLAR
If solar generation cannot satisfy the load:
If battery SOC > 20%
        ↓
     BATTERY
Otherwise:
        ↓
        GRID
Solar generation is also used to charge the battery whenever:
solar > load

⚡ Grid Fallback
The grid acts as the final energy source when renewable energy and battery storage are insufficient.
Typical condition:
solar < load
AND
battery_soc <= 20%
The grid can also become active when:
Battery is unavailable
Solar is insufficient
Peak-demand conditions require fallback
Fault recovery returns the system to a safe default state

💰 Time-of-Use Tariff Management
The controller implements three tariff periods.
Period	Slot	Rate
Night	00	₹5/unit
Day	01	₹8/unit
Peak Evening	10	₹10/unit
Priority:
Peak Evening
     ↓
    Day
     ↓
    Night
Peak electricity is intentionally more expensive in the model, encouraging the controller to utilize stored energy or renewable generation during expensive periods.

🧠 Intelligent Source Selection
The FSM considers several parameters simultaneously:
                Load Demand
                    │
                    ▼
Solar Generation ─► FSM ◄─ Battery SOC
                    │
                    ├── Tariff
                    │
                    ├── Faults
                    │
                    └── Time of Day
                    │
                    ▼
          ┌─────────┼─────────┐
          ▼         ▼         ▼
        SOLAR     BATTERY     GRID

🔮 Load Prediction
The FSM includes a simple load prediction mechanism.
The predicted load is calculated using:
predicted_load = 2 × current_load - previous_load
This provides a simple linear extrapolation of the load trend.
If predicted demand becomes significantly higher than available solar power, the FSM can request battery pre-charging.
The configured prediction margin is:
PRED_MARGIN = 200 W
This allows the battery to be prepared for an anticipated increase in demand.

🔄 FSM Hysteresis
Rapid switching between power sources is undesirable.
For example:
SOLAR → GRID → SOLAR → GRID → ...
could occur if solar generation fluctuates around the load demand.
To reduce this behavior, the FSM uses a state hold timer.
Configured minimum state hold:
MIN_HOLD = 8 clock cycles
The controller therefore avoids changing state immediately unless a higher-priority fault or idle condition requires it.

🛡️ Fault Detection & Protection
The controller monitors several fault conditions.
1. Battery Over-Temperature
battery_overtemp = 1
causes the FSM to enter:
FAULT
2. Solar Fault
A solar fault can trigger the fault state depending on the operating tariff/condition.
Normal low solar generation is not automatically treated as a fault. Low solar availability is handled as a source-selection condition.
3. Overload Protection
The system has an overload limit:
OVERLOAD_LIMIT = 2300 W
Automatic overload detection:
overload_auto = total_load > 2300 W
The controller also accepts an external overload signal.
The final overload signal is:
overload = overload_in OR overload_auto
4. Grid Fault
If the grid becomes unavailable while the controller is using the grid, the FSM can transition into the fault state.

🚨 Fault Mode
When FAULT is active:
solar_mode   = 0
battery_mode = 0
grid_mode    = 0
All appliance supplies are also disabled:
ac_supply     = 0
fridge_supply = 0
wm_supply     = 0
fan_supply    = 0
bulb_supply   = 0
The final served load becomes:
final_load = 0
This provides a fail-safe shutdown behavior in the digital controller.

🔢 Fault Codes
The FSM provides a 3-bit fault_code output for fault diagnostics.
The testbench verifies fault conditions including:
Overload
Solar fault
Multiple simultaneous faults
Fault clearing/recovery
SOC boundary conditions

🔌 Load Priority Management
load_priority_manager.v implements priority-based load shedding.
When available power is limited, appliances are considered in priority order:
1. Refrigerator
2. Fan
3. Bulb
4. Washing Machine
5. Air Conditioner
The idea is:

Available Power
       ↓
Check Refrigerator
       ↓
Check Fan
       ↓
Check Bulb
       ↓
Check Washing Machine
       ↓
Check Air Conditioner
Lower-priority loads are disconnected when the available power budget cannot support them.
This prevents unnecessary overload and allows essential appliances to remain operational.

📁 Repository Structure
Real-Time-Smart-Energy-Source-Controller/
│
├── sourcecode.v
│   └── Top-level Home Energy Source Controller
│
├── FSM_energy_controller.v
│   └── Main energy-source FSM
│
├── battery_soc_controller.v
│   └── Battery SOC charging/discharging model
│
├── load_priority_manager.v
│   └── Priority-based appliance load management
│
├── power_mode.v
│   └── Basic energy-source selection controller
│
├── load_calculation.v
│   └── Load calculation logic
│
├── solar_generation.v
│   └── Solar generation model
│
├── energy_consumption.v
│   └── Energy consumption calculation
│
├── home_energy_control_tb.v
│   └── System-level verification testbench
│
├── LICENSE
│   └── Project license
│
└── README.md
    └── Project documentation

🧩 Module Description
sourcecode.v
Top-level integration module.
Responsibilities:
Calculate appliance load
Select tariff
Aggregate faults
Interface with FSM
Interface with battery SOC controller
Generate appliance supply signals
Apply fault protection
Calculate operating cost
FSM_energy_controller.v

Core decision-making module.
Responsibilities:
Energy-source selection
FSM state management
Fault handling
Battery SOC evaluation
Load prediction
Peak-demand precharge request
PWM generation
State hysteresis
battery_soc_controller.v

Models battery State of Charge.
Responsibilities:
Initialize SOC
Charge battery
Discharge battery
Prevent SOC overflow
Prevent SOC from becoming negative
Handle idle battery behavior
Respond to precharge requests
load_priority_manager.v

Implements priority-based load management.
Responsibilities:
Evaluate available power
Enable appliances according to priority
Shed lower-priority loads
Calculate actual served load
power_mode.v

Contains a simpler combinational energy-source selection implementation based on:
Load
Solar Generation
Battery SOC
Day/Night
It represents the basic source-selection concept used by the larger controller architecture.

load_calculation.v
Calculates aggregate power demand from appliance inputs.

solar_generation.v
Models the available solar generation used by the controller.

energy_consumption.v
Provides energy-consumption-related calculations used by the project.

home_energy_control_tb.v
System-level verification environment.

The testbench checks:
Source-selection behavior
FSM transitions
Battery SOC behavior
Fault handling
Overload protection
Solar fault handling
Multiple simultaneous faults
Fault recovery
Appliance supply behavior
Cost calculations
Source exclusivity
The testbench also maintains statistics for source usage and appliance activation.

🧪 Verification Strategy
The design is verified using a behavioral Verilog testbench.
The testbench checks the expected relationship:
Only one primary source should be active
For example:
SOLAR   = 1
BATTERY = 0
GRID    = 0

or:
SOLAR   = 0
BATTERY = 1
GRID    = 0

or:
SOLAR   = 0
BATTERY = 0
GRID    = 1

During fault:
SOLAR   = 0
BATTERY = 0
GRID    = 0
FAULT   = 1
The testbench also validates that appliances are disconnected when a fault occurs.

🧪 Example Operating Scenarios
Scenario 1 — Solar Available
Load = 1000 W
Solar = 1500 W
SOC = 50%
Day = TRUE

Since:
Solar > Load
the controller selects:
SOLAR
and the surplus solar can contribute to battery charging.

Scenario 2 — Solar Insufficient, Battery Available
Load = 1800 W
Solar = 1000 W
SOC = 70%
Solar cannot satisfy the complete demand.
Since battery SOC is above the minimum threshold:
BATTERY
is selected.

Scenario 3 — Battery Low
Load = 1800 W
Solar = 500 W
SOC = 15%
Battery SOC is below the safe discharge threshold.
Therefore:
GRID
is selected.

Scenario 4 — No Load
Load = 0 W
The controller enters:
IDLE
No energy source is activated.

Scenario 5 — Overload
Load > 2300 W
The automatic overload detector asserts:
overload_auto = 1
The FSM transitions to:
FAULT
All appliance supplies are disabled.

Scenario 6 — Battery Over-Temperature
battery_overtemp_in = 1
The controller immediately prioritizes fault handling and enters:
FAULT
The energy sources and appliance supplies are disabled.

💻 Simulation
The project can be simulated using an open-source Verilog simulator such as Icarus Verilog.
Compile
iverilog -o simv sourcecode.v \
FSM_energy_controller.v \
battery_soc_controller.v \
load_calculation.v \
solar_generation.v \
energy_consumption.v \
load_priority_manager.v \
power_mode.v \
home_energy_control_tb.v
Run Simulation
vvp simv
The testbench prints operating conditions, selected source, SOC, load, tariff, cost, and appliance supply states.

📊 Waveform Analysis
For waveform-based debugging, generate a VCD file from the testbench and open it using GTKWave.
gtkwave home_energy_control.vcd
Important signals to observe:
clk
reset
total_load
solar_generation
battery_soc
solar_mode
battery_mode
grid_mode
fault_mode
idle_mode
fault_code
ac_supply
fridge_supply
wm_supply
fan_supply
bulb_supply
tariff_per_unit
The waveform can be used to verify:
FSM state transitions
Battery charging/discharging
Source switching
Fault response
Load changes
Tariff changes
Appliance gating

🧮 Operating Cost Model
The controller includes a simplified operating-cost model.
Grid Cost
When grid power is active:
grid_cost = final_load × tariff_per_unit
Otherwise:
grid_cost = 0
Battery Wear Cost
When battery power is active:
battery_wear_cost = final_load × BATTERY_COST_PER_UNIT
The configured battery wear-cost coefficient is:
BATTERY_COST_PER_UNIT = 2
Total Cost
total_operating_cost =grid_cost+battery_wear_cost
This allows the design to consider not only energy availability but also an approximate economic cost.

🛠️ Technology Stack
Category	Technology
HDL	Verilog HDL
Simulation	Icarus Verilog
Waveform Analysis	GTKWave
Development	VS Code
Version Control	Git / GitHub
Design Concept	FSM-based digital control
Verification	Verilog Testbench

🧠 Digital Design Concepts Demonstrated
This project demonstrates practical implementation of:
Finite State Machines
Moore-style control architecture
Sequential logic
Combinational logic
Clocked state transitions
Asynchronous reset
Registers
Counters
Priority logic
Fault detection
Hysteresis
PWM generation
State-of-charge modeling
Load management
Hardware-oriented decision logic
RTL simulation
Testbench development
Waveform debugging

🔬 Design Flow
Problem Definition
       ↓
Energy Source Requirements
       ↓
Load Modeling
       ↓
Solar Generation Modeling
       ↓
Battery SOC Modeling
       ↓
Tariff Logic
       ↓
Fault Detection
       ↓
FSM Design
       ↓
RTL Implementation
       ↓
Testbench Development
       ↓
Simulation
       ↓
Waveform Analysis
       ↓
Debugging & Verification

🚧 Current Limitations
This is an RTL simulation model and not a production-ready residential energy controller.
Current limitations include:
Solar generation is modeled digitally rather than measured from a physical PV system.
Battery SOC is represented using a simplified percentage-based model.
Battery charging/discharging is represented using fixed SOC steps rather than electrochemical battery equations.
Power and energy calculations are simplified for digital simulation.
Tariff values are model parameters rather than live utility pricing.
No physical sensors or power electronics are directly controlled.
No FPGA/ASIC implementation has been demonstrated yet.
No MPPT algorithm is implemented.
No real-time communication interface is included.
These limitations define clear directions for future hardware implementation.

🚀 Future Improvements
Possible extensions include:
Hardware Implementation
FPGA implementation
ASIC-oriented RTL optimization
Synthesis and timing analysis
Cadence RTL-to-GDS flow
Renewable Energy
MPPT-based solar controller
Variable solar generation model
Solar irradiance input
PV panel electrical model
Battery Management
Real battery charging model
Battery voltage/current monitoring
Temperature monitoring
State-of-Health estimation
Coulomb-counting SOC estimation
Smart Load Management
Dynamic appliance prioritization
Demand-response control
Peak-load prediction
Appliance scheduling
Communication
UART
SPI
I²C
CAN
IoT/cloud monitoring
Advanced Control
Predictive energy management
Dynamic electricity pricing
AI-based load prediction
Optimization-based source scheduling

📈 Project Significance
The project demonstrates how a real-world energy-management problem can be translated into a digital hardware control architecture.
Instead of using a purely software-based decision system, the project models the decision engine using synthesizable-style RTL concepts such as:
Inputs
  ↓
Combinational Decision Logic
  ↓
FSM
  ↓
Sequential State Updates
  ↓
Control Outputs

This makes the project relevant to areas such as:

RTL Design
Digital IC Design
FPGA Design
Embedded Hardware
Smart Energy Systems
Power Management Controllers
Hardware Control Systems

👩‍💻 Author
Vaishali Sharma
B.Tech – Electronics & Communication Engineering
Interested in:
VLSI
RTL Design
Verilog
Digital IC Design
Hardware Architecture
Energy-Efficient Digital Systems

📄 License
This project is released under the Unlicense.
See LICENSE for details.
⭐ Project Highlights
✔ Verilog RTL implementation
✔ FSM-based source selection
✔ Solar + Battery + Grid management
✔ Battery SOC controller
✔ Load-priority management
✔ Tariff-aware decision making
✔ Load prediction
✔ FSM hysteresis
✔ Fault detection and protection
✔ Overload protection
✔ System-level testbench
✔ Simulation-based verification
✔ GTKWave waveform analysis

🔗 Repository
Real-Time Smart Energy Source Controller



The architecture itself is substantially richer than the two-line README currently suggests: the FSM has `SOLAR`, `BATTERY`, `GRID`, `FAULT`, and `IDLE` states, with SOC thresholds, prediction, PWM, and hysteresis. :contentReference[oaicite:5]{index=5}


:contentReference[oaicite:6]{index=6}
