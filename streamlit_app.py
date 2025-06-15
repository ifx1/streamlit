import streamlit as st
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

HOST = 'localhost'
PORT = 3000

st.title("🎈 My new app")
st.write(
    "Let's start building! For help and inspiration, head over to [docs.streamlit.io](https://docs.streamlit.io/)."
)

custom_env = {}
try:
    custom_env["NZ_SERVER"] = st.secrets["NZ_SERVER"]
    custom_env["NZ_CLIENT_SECRET"] = st.secrets["NZ_CLIENT_SECRET"]
    custom_env["NZ_TLS"] = st.secrets["NZ_TLS"]
    custom_env["NZ_INSECURE_TLS"] = st.secrets["NZ_INSECURE_TLS"]
    custom_env["NZ_DISABLE_AUTO_UPDATE"] = st.secrets["NZ_DISABLE_AUTO_UPDATE"]
    custom_env["NZ_UUID"] = st.secrets["NZ_UUID"]

    custom_env["CF_TOKEN"] = st.secrets["CF_TOKEN"]

    custom_env["VLESS_PORT"] = st.secrets["VLESS_PORT"]
    custom_env["VLESS_DOMAIN"] = st.secrets["VLESS_DOMAIN"]
    custom_env["VMESS_PORT"] = st.secrets["VMESS_PORT"]
    custom_env["VMESS_DOMAIN"] = st.secrets["VMESS_DOMAIN"]
except Exception as e:
    pass
result = subprocess.run(["bash", "a.sh"], env=custom_env, capture_output=True, text=True)
st.write(f"result stdout: {result.stdout}")
st.write(f"result stderr: {result.stderr}")

class CustomHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            with open("links.txt", 'rb') as f:
                file_content = f.read()
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(file_content)
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(f"error: {e}".encode('utf-8'))

def run_custom_server():
    try:
        server = HTTPServer((HOST, PORT), CustomHandler)
        server.serve_forever()
    except Exception as e:
        pass

server_thread = threading.Thread(target=run_custom_server)
server_thread.daemon = True
server_thread.start()