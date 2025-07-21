import json
import argparse

def extract_vmaf_lines(json_path, output_path):
    with open(json_path) as f:
        data = json.load(f)

    frames = data.get("frames", [])
    with open(output_path, 'w') as out:
        for frame in frames:
            frame_num = frame.get("frameNum")
            vmaf = frame.get("metrics", {}).get("vmaf")
            if frame_num is not None and vmaf is not None:
                out.write(f"frameNum: {frame_num}, vmaf: {vmaf:.6f}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extrai frameNum e VMAF de um JSON e salva em arquivo.")
    parser.add_argument("json_path", help="Caminho para o arquivo .json com resultados do VMAF")
    parser.add_argument("output_path", help="Arquivo de saída (.txt)")
    args = parser.parse_args()

    extract_vmaf_lines(args.json_path, args.output_path)
