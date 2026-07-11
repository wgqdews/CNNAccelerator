import numpy as np
import onnx
import onnxruntime as ort
from onnx import numpy_helper
import os

# 建立輸出資料夾
output_dir = "verilog_test_vectors"
readable_dir = "readable_channels"  # 專門放人類閱讀的二維矩陣
os.makedirs(output_dir, exist_ok=True)
os.makedirs(readable_dir, exist_ok=True)

# ==========================================
# Step 1: 讀取原始模型與測資
# ==========================================
model_path = "squeezenet1.0-12-int8.onnx"  # 請替換成你的 ONNX 模型路徑
input_pb_path = "input_0.pb"

model = onnx.load(model_path)

input_tensor = onnx.TensorProto()
with open(input_pb_path, "rb") as f:
    input_tensor.ParseFromString(f.read())
input_data = numpy_helper.to_array(input_tensor)

# ==========================================
# Step 2: 修改模型，將所有中間層設為輸出節點
# ==========================================
while len(model.graph.output) > 0:
    model.graph.output.pop()

for node in model.graph.node:
    for output_name in node.output:
        updated_output = onnx.ValueInfoProto()
        updated_output.name = output_name
        model.graph.output.append(updated_output)

dump_model_path = "model_all_outputs.onnx"
onnx.save(model, dump_model_path)

# ==========================================
# Step 3: 執行模型並導出量化後的整數資料
# ==========================================
input_name = model.graph.input[0].name
session = ort.InferenceSession(dump_model_path)
output_names = [out.name for out in session.get_outputs()]
outputs = session.run(output_names, {input_name: input_data})

# 1. 存入原始的輸入資料 (轉為 8-bit Hex 攤平檔)
input_uint8 = np.round(input_data.flatten()).astype(np.uint8)
np.savetxt(f"{output_dir}/input_0.txt", input_uint8, fmt='%02x')

# 2. 遍歷每一層的輸出
for idx, (name, tensor) in enumerate(zip(output_names, outputs)):
    safe_name = name.replace("/", "_").replace(":", "_")
    
    # 將該層的 Tensor 四捨五入
    tensor_round = np.round(tensor)
    
    # 【關鍵】強制轉成 uint8，自動處理好負數的二補數 Hex 表現
    tensor_uint8 = tensor_round.astype(np.uint8)
    
    # 2a. 存一份攤平的 8-bit Hex 資料供 Verilog 測試平台使用
    filename_flat = f"{output_dir}/layer_{idx}_{safe_name}.txt"
    np.savetxt(filename_flat, tensor_uint8.flatten(), fmt='%02x')
    
    # 2b. 生成人類閱讀的「二維通道 Hex 矩陣」
    if tensor_uint8.ndim == 4:
        feat_map = tensor_uint8[0]  # [Channel, Height, Width]
    elif tensor_uint8.ndim == 3:
        feat_map = tensor_uint8     # [Channel, Height, Width]
    else:
        # 如果是 1D/2D 向量，直接 8-bit Hex 存檔
        filename_vector = f"{output_dir}/layer_{idx}_{safe_name}_vector.txt"
        np.savetxt(filename_vector, tensor_uint8.flatten(), fmt='%02x')
        continue

    channels, height, width = feat_map.shape
    layer_folder = f"{readable_dir}/layer_{idx}_{safe_name}"
    os.makedirs(layer_folder, exist_ok=True)
    
    # 逐個 Channel 輸出二維 Hex 矩陣
    for c in range(channels):
        channel_matrix = feat_map[c]
        channel_filename = f"{layer_folder}/channel_{c}.txt"
        
        # 使用 %02x，輸出的矩陣會非常整齊（全部都是 2 個字元，如 00, 0a, ff）
        np.savetxt(channel_filename, channel_matrix, fmt='%02x')

    print(f"Layer {idx} [{name}] -> 已導出 8-bit Hex 矩陣至 {layer_folder}/")

# 清理臨時模型
if os.path.exists(dump_model_path):
    os.remove(dump_model_path)

print("\n🎉 量化整數資料（已去除小數點）生成完畢！")