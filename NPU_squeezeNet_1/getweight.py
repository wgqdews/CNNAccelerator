import numpy as np
import onnx
from onnx import numpy_helper
import os

# 建立放權重的資料夾
weights_dir = "verilog_weights"
os.makedirs(weights_dir, exist_ok=True)

# 載入 ONNX 模型
model_path = "squeezenet1.0-12-int8.onnx"  # 替換成你的 ONNX 模型路徑
model = onnx.load(model_path)

print("開始導出各層的 Kernel 與 Bias (量化為純整數)... \n")

# 遍歷模型中所有的 Initializers (權重、偏權值等常數)
for initializer in model.graph.initializer:
    name = initializer.name
    # 清理檔名特殊字元
    safe_name = name.replace("/", "_").replace(":", "_")
    
    # 將 ONNX tensor 轉為 NumPy 陣列
    weight_tensor = numpy_helper.to_array(initializer)
    
    # 進行量化與四捨五入，轉成純整數，去除 .0000
    weight_int = np.round(weight_tensor).astype(np.int32)
    
    # 定義存檔路徑
    filename = f"{weights_dir}/{safe_name}.txt"
    
# 根據維度決定儲存格式
    if weight_int.ndim == 0:
        # 0D 純量常數 (如 scale, zero_point)
        # 強制轉成 uint8，並以 2 碼 Hex 儲存
        val_uint8 = np.array([weight_int]).astype(np.uint8)
        np.savetxt(filename, val_uint8, fmt='%02x')
        print(f"【Scalar 0D】 {name} -> 已轉 8-bit Hex 存至 {filename}")

    elif weight_int.ndim == 1:
        # 1D 陣列 (既然你確認了是 8-bit Bias 或是其他 8-bit 參數)
        # 強制轉成 uint8，自動處理負數二補數
        weight_uint8 = weight_int.astype(np.uint8)
        np.savetxt(filename, weight_uint8, fmt='%02x')
        print(f"【1D Array】 {name} -> Shape: {weight_int.shape} -> 已轉 8-bit Hex 存至 {filename}")
        
    elif weight_int.ndim == 4:
        # Convolution Kernel 4D
        kernel_flat = weight_int.flatten()
        # 強制轉成 uint8 型態
        kernel_uint8 = kernel_flat.astype(np.uint8)
        np.savetxt(filename, kernel_uint8, fmt='%02x')
        print(f"【Kernel 4D】 {name} -> Shape: {weight_int.shape} (已攤平轉 8-bit Hex) -> 已存至 {filename}")
        
        # 額外存一個人類好讀的格式（維持十進位，方便對帳）
        human_dir = f"{weights_dir}/{safe_name}_human"
        os.makedirs(human_dir, exist_ok=True)
        oc, ic, kh, kw = weight_int.shape
        for o in range(min(oc, 4)): 
            for i in range(min(ic, 1)):
                np.savetxt(f"{human_dir}/outC_{o}_inC_{i}.txt", weight_int[o, i], fmt='%4d')
    else:
        # 其他多維權重
        other_flat = weight_int.flatten()
        other_uint8 = other_flat.astype(np.uint8)
        np.savetxt(filename, other_uint8, fmt='%02x')
        print(f"【Other {weight_int.ndim}D】 {name} -> Shape: {weight_int.shape} -> 已轉 8-bit Hex 存至 {filename}")
        
print("\n🎉 所有權重與偏權值已成功導出為純整數文字檔！")