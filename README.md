# Vigil - Industrial Safety Monitoring System

**"Industrial Intelligence, Simplified."**

Vigil is a cutting-edge industrial safety and monitoring solution designed to protect machinery and personnel through real-time data analysis and instant alerts. By bridging the gap between hardware sensors and modern mobile interfaces, Vigil ensures that critical infrastructure remains safe, efficient, and operational.

## 🚀 Key Features & Benefits

### 1. Real-Time Monitoring
*   **Live Data:** Monitor Temperature, Voltage, Vibration, and Gas levels instantly.
*   **Visual Dashboard:** Intuitive charts and gauges provide a clear view of system health.

### 2. Intelligent Alerts
*   **Instant Notifications:** Receive push notifications for critical events (e.g., Gas Leak, High Temperature).
*   **Severity Levels:** Clear distinction between "Safe", "Warning", and "Danger" states.

### 3. AI-Powered Insights
*   **Predictive Maintenance:** AI analysis of historical data to predict potential failures before they happen.
*   **Smart Summaries:** Get natural language summaries of your system's status.

### 4. Voice Control
*   **Hands-Free Operation:** Ask Vigil for status updates using voice commands.
*   **Text-to-Speech:** The app speaks back, keeping you informed without looking at the screen.

### 5. Comprehensive Reporting
*   **PDF Reports:** Generate and share detailed safety reports.
*   **Historical Data:** Access past performance data to identify trends.

## 🏗️ System Architecture

The Vigil ecosystem consists of three main components:

1.  **Hardware (Edge):** GSM-enabled sensors (ATmega + SIM800) collect and transmit data.
2.  **Backend (Core):** A robust Node.js/Express server that processes data, manages the SQLite database, and serves APIs.
3.  **Mobile App (Interface):** A high-performance Flutter application for monitoring and control.

## 📂 Project Structure

*   **`Backend/`**: Contains the Node.js Express server, database, and API logic.
*   **`Mobile_App/`**: Contains the Flutter mobile application source code.

## 🏁 Getting Started

Please refer to the `README.md` files in the respective folders for detailed setup instructions:

*   [Backend Documentation](./Backend/README.md)
*   [Mobile App Documentation](./Mobile_App/README.md)
