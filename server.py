from flask import Flask, jsonify, request
import os
import subprocess
import time
import platform
import json
import glob
import shutil
import urllib.request

# Global variable for serving model state
_llamacpp_serving_model: str | None = None
_llamacpp_process = None

app = Flask(__name__)

def _detect_llamacpp_platform():
    system = platform.system().lower()
    machine = platform.machine().lower()
    if system == "darwin":
        if machine == "arm64":
            return {"asset": "macos-arm64", "ext": "tar.gz"}
        return {"asset": "macos-x64", "ext": "tar.gz"}
    if system == "linux":
        if machine == "aarch64":
            return {"asset": "ubuntu-arm64", "ext": "tar.gz"}
        if shutil.which("rocm-smi"):
            return {"asset": "ubuntu-rocm-7.2-x64", "ext": "tar.gz"}
        if shutil.which("nvidia-smi"):
            return {"asset": "ubuntu-x64", "ext": "tar.gz"}
        return {"asset": "ubuntu-x64", "ext": "tar.gz"}
    if system == "windows":
        return {"asset": "win-cpu-x64", "ext": "zip"}
    raise RuntimeError(f"Unsupported platform: {system} {machine}")

def _get_latest_llamacpp_tag():
    import urllib.request
    import json
    try:
        with urllib.request.urlopen("https://api.github.com/repos/ggml-org/llama.cpp/releases/latest") as resp:
            data = json.loads(resp.read())
            return data["tag_name"]
    except Exception as e:
        return "b9739"

def _build_download_url(tag, platform_info):
    asset = platform_info["asset"]
    ext = platform_info["ext"]
    return f"https://github.com/ggml-org/llama.cpp/releases/download/{tag}/llama-{tag}-bin-{asset}.{ext}"

def _stop_llamacpp():
    global _llamacpp_process, _llamacpp_serving_model
    if _llamacpp_process:
        try:
            _llamacpp_process.terminate()
            _llamacpp_process.wait(timeout=5)
        except Exception:
            _llamacpp_process.kill()
        _llamacpp_process = None
    _llamacpp_serving_model = None

def _start_llamacpp(model_path: str):
    try:
        cmd = [
            'llama-server',
            '-m', model_path,
            '--host', '127.0.0.1',
            '--port', '8080',
            '-c', '8192',
            '-ngl', '0',
            '--flash-attn', '1'
        ]
        process = subprocess.Popen(cmd)
        global _llamacpp_process
        _llamacpp_process = process
        _llamacpp_serving_model = model_path
        return True
    except Exception as e:
        print(f"Failed to start llama-server: {e}")
        return False

@app.route('/api/local-backends/models/gguf', methods=['GET'])
def list_gguf_models():
    models_dir = os.path.expanduser('~/.cache/llmfit/models/')
    gguf_models = []
    if not os.path.exists(models_dir):
        return jsonify({'error': 'Models directory not found'}), 404
    for filename in os.listdir(models_dir):
        if filename.endswith('.gguf'):
            model_path = os.path.join(models_dir, filename)
            try:
                size = os.path.getsize(model_path)
                fit_score = 0.95  # placeholder
                gguf_models.append({
                    'name': filename,
                    'size': size,
                    'fit_score': fit_score,
                    'path': model_path
                })
            except OSError:
                continue
    gguf_models.sort(key=lambda x: x['fit_score'], reverse=True)
    return jsonify({'models': gguf_models})

@app.route('/api/local-backends/llamacpp/serve', methods=['POST'])
def serve_gguf_model():
    data = request.get_json()
    if not data or 'model' not in data:
        return jsonify({'error': 'model is required'}), 400
    model_name = data['model']
    model_path = os.path.expanduser(f'~/.cache/llmfit/models/{model_name}')
    if not os.path.exists(model_path):
        return jsonify({'error': 'Model file does not exist'}), 404

    _stop_llamacpp()
    if not _start_llamacpp(model_path):
        return jsonify({'error': 'Failed to start llama-server'}), 500

    return jsonify({
        'status': 'success',
        'serving_model': model_name,
        'message': 'Server started'
    }), 200

@app.route('/status', methods=['GET'])
def get_status():
    llama_cpp_installed = shutil.which('llama-server') is not None
    llama_cpp_running = _llamacpp_process is not None and _llamacpp_process.poll() is None
    return jsonify({
        'gguf_available': os.path.exists(os.path.expanduser('~/.cache/llmfit/models/')),
        'llama_cpp_installed': llama_cpp_installed,
        'llama_cpp_running': llama_cpp_running,
        'serving_model': os.path.basename(_llamacpp_serving_model) if _llamacpp_serving_model else None
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)