#!/usr/bin/env python3
import time
from simple_pid import PID
import RPi.GPIO as GPIO
import argparse
from flask import Flask, render_template, request
import glob

app = Flask(__name__)

# GPIO pin numbers for the relays
HEATING_RELAY_PIN = 17
COOLING_RELAY_PIN = 18

# PID parameters (default values)
KP = 1.0  # Proportional gain
KI = 0.1  # Integral gain
KD = 0.01  # Derivative gain
SETPOINT = 20.0  # Default desired temperature in Celsius

# Temperature tolerance (+/- degrees from the setpoint)
TEMP_TOLERANCE = 0.5


def read_temperature(sensor_id):
    # Function to read temperature from a DS18B20 thermistor with given sensor_id
    # Sensor_id is the unique identifier of the DS18B20 sensor

    # Path to the sensor file (use your actual path)
    sensor_file = f"/sys/bus/w1/devices/{sensor_id}/w1_slave"

    try:
        with open(sensor_file, 'r') as f:
            lines = f.readlines()

        if lines[0].strip().endswith("YES"):
            temperature_data = lines[1].split("=")[1]
            temperature_celsius = float(temperature_data) / 1000.0
            return temperature_celsius
        else:
            return None
    except Exception as e:
        print(f"Error reading temperature from sensor {sensor_id}: {e}")
        return None

def read_beer_temperature():
    beer_sensor_id = "28-000000000000"  # Replace with the actual sensor ID
    return read_temperature(beer_sensor_id)

def read_fridge_air_temperature():
    air_sensor_id = "28-111111111111"  # Replace with the actual sensor ID
    return read_temperature(air_sensor_id)

def read_room_temperature():
    room_sensor_id = "28-222222222222"  # Replace with the actual sensor ID
    return read_temperature(room_sensor_id)

def control_heating_relay(state):
    # Function to control the heating relay
    # The state argument should be True to turn ON the relay, and False to turn it OFF

    # Code to control the heating relay using RPi.GPIO
    GPIO.output(HEATING_RELAY_PIN, state)

def control_cooling_relay(state):
    # Function to control the cooling relay
    # The state argument should be True to turn ON the relay, and False to turn it OFF

    # Code to control the cooling relay using RPi.GPIO
    GPIO.output(COOLING_RELAY_PIN, state)
    
def pid_autotune():
    # Automatic PID tuning using Ziegler-Nichols method
    print("Starting PID autotuning...")
    
    # Initial P, I, and D gains
    pid = PID(KP, KI, KD, setpoint=SETPOINT)
    pid.output_limits(-1.0, 1.0)
    
    # Step 1: Set I and D gains to zero
    pid.tunings = (KP, 0.0, 0.0)

    # Step 2: Increase P gain until oscillations occur
    max_oscillations = 20
    ku = 0.0
    for i in range(1, max_oscillations + 1):
        kp_candidate = KP * i / 10.0
        pid.tunings = (kp_candidate, 0.0, 0.0)
        time.sleep(5)  # Wait for the system to settle
        avg_temp = (read_beer_temperature() + read_fridge_air_temperature() + read_room_temperature()) / 3.0
        print(f"Attempt {i}: P = {kp_candidate:.2f}, Average Temperature = {avg_temp:.2f} °C")
        
        # Step 3: Measure the period of oscillations
        # The user should manually stop the loop if oscillations are observed
        if i > 1:
            choice = input("Do you observe oscillations? (y/n): ").lower()
            if choice == 'y':
                ku = kp_candidate
                break
        else:
            print("Waiting for oscillations to occur...")

    if ku == 0.0:
        print("Automatic tuning failed. Please try again.")
        return

    # Step 4: Calculate PID gains
    tu = 10.0  # Assuming a typical period of oscillation (adjust if needed)
    kp = 0.6 * ku
    ki = 1.2 * ku / tu
    kd = 0.075 * ku * tu

    print(f"PID gains obtained: KP = {kp:.2f}, KI = {ki:.2f}, KD = {kd:.2f}")
    
    # Save the obtained gains to a file for later use
    with open('pid_constants.txt', 'w') as f:
        f.write(f"KP={kp}\nKI={ki}\nKD={kd}")

    print("PID autotuning completed.")

@app.route('/')
def index():
    return render_template('index.html', setpoint=SETPOINT, kp=KP, ki=KI, kd=KD)

@app.route('/control', methods=['POST'])
def control():
    setpoint = float(request.form['setpoint'])
    kp = float(request.form['kp'])
    ki = float(request.form['ki'])
    kd = float(request.form['kd'])
    autotune = bool(request.form.get('autotune'))

    # Save the new setpoint and PID constants to a file for later use
    with open('pid_constants.txt', 'w') as f:
        f.write(f"KP={kp}\nKI={ki}\nKD={kd}")

    # Start or restart the fermentation fridge program with the updated parameters
    main(setpoint, kp, ki, kd, autotune)
    return 'Started the fermentation fridge program.'

def main(setpoint, kp, ki, kd, autotune):
    # Initialize GPIO settings
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(HEATING_RELAY_PIN, GPIO.OUT)
    GPIO.setup(COOLING_RELAY_PIN, GPIO.OUT)

    if autotune:
        pid_autotune()

    # Initialize PID controller with provided or default gains and setpoint
    pid = PID(kp, ki, kd, setpoint=setpoint, sample_time=1)
    pid.output_limits = (-1.0, 1.0)  # Restrict the PID output between -1 and 1

    while True:
        # Read temperatures from the thermistors
        beer_temp = read_beer_temperature()
        fridge_air_temp = read_fridge_air_temperature()
        room_temp = read_room_temperature()

        # Compute the average temperature from the three thermistors
        avg_temp = (beer_temp + fridge_air_temp + room_temp) / 3.0

        # Calculate PID output
        pid_output = pid(avg_temp)

        # Control the relays based on the PID output
        if pid_output > TEMP_TOLERANCE:
            control_cooling_relay(True)
            control_heating_relay(False)
        elif pid_output < -TEMP_TOLERANCE:
            control_cooling_relay(False)
            control_heating_relay(True)
        else:
            control_cooling_relay(False)
            control_heating_relay(False)

        # Print the temperatures and PID output for debugging (you can remove this in the final version)
        print(f"Beer Temp: {beer_temp:.2f} °C, Fridge Air Temp: {fridge_air_temp:.2f} °C, Room Temp: {room_temp:.2f} °C, Avg Temp: {avg_temp:.2f} °C, PID Output: {pid_output:.2f}")

        time.sleep(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PID-controlled fermentation fridge program")
    parser.add_argument("--kp", type=float, default=1.0, help="Proportional gain (KP)")
    parser.add_argument("--ki", type=float, default=0.1, help="Integral gain (KI)")
    parser.add_argument("--kd", type=float, default=0.01, help="Derivative gain (KD)")
    parser.add_argument("--setpoint", type=float, default=20.0, help="Desired temperature setpoint (Celsius)")
    args = parser.parse_args()

    # Save the initial setpoint and PID constants to a file for later use
    with open('pid_constants.txt', 'w') as f:
        f.write(f"KP={args.kp}\nKI={args.ki}\nKD={args.kd}")

    # Start the fermentation fridge program with the command-line arguments
    main(args.setpoint, args.kp, args.ki, args.kd, autotune=False)

    # Run the Flask web app on port 5000, accessible from any computer on the network
    app.run(host='0.0.0.0', port=5000)