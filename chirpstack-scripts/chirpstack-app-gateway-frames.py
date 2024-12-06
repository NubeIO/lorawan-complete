import websocket
import json
from datetime import datetime

WS_URL = "ws://<IP>:8080/api/gateways/<GW_EUI>/frames"
API_JWT = "<JWT>"

def on_message(ws, message):
    print(message)

def on_error(ws, error):
    # print("WebSocket error:", error)
    pass

def on_close(ws, close_status_code, close_msg):
    # print("WebSocket closed:", close_status_code, close_msg)
    pass

def on_open(ws):
    # print("WebSocket connection opened")
    pass

def main():
    ws = websocket.WebSocketApp(
        WS_URL,
        header=[f"sec-websocket-protocol: Bearer, {API_JWT}"],
        on_message=on_message,
        on_open=on_open,
        on_close=on_close,
        on_error=on_error
    )
    ws.run_forever()

if __name__ == "__main__":
    main()
