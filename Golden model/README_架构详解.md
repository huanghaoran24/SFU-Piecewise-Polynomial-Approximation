# Golden Model 架构详解与使用指南

## 📋 目录

- [1. 项目概述](#1-项目概述)
- [2. 文件架构](#2-文件架构)
- [3. 算法原理](#3-算法原理)
- [4. 使用方法](#4-使用方法)
- [5. Python对照](#5-python对照)

---

## 1. 项目概述

这是一个用于**分段二次多项式插值逼近特殊函数**的硬件黄金模型（Golden Model）。

### 核心目标

使用简单的硬件运算（查表 + 乘法 + 加法）快速逼近复杂的特殊函数，如：

- 倒数 (1/x)
- 平方根 (√x)
- 倒数平方根 (1/√x)
- 指数函数 (2^x)
- 对数函数 (log₂x)
- 三角函数 (sin, cos)

### 关键优势

✅ **硬件友好** - 无需复杂的除法器或超越函数单元
✅ **精度可控** - 通过调整分段数实现精度/面积权衡
✅ **速度快** - 固定时延的查表和乘加运算
✅ **可扩展** - 支持多种函数，易于添加新函数

---

## 2. 文件架构

### 2.1 层级结构

```
Golden Model/
├── 第1层: 主入口
│   └── GoldenModel.m          # 主程序，完整流程
│
├── 第2层: 核心算法
│   ├── coeff.m                # 系数定义（10种函数）
│   ├── loadLUTs.m             # 加载查找表
│   └── getLUT.m               # 优化查找表存储
│
├── 第3层: 数据处理
│   ├── coeffbin.m             # 系数转二进制
│   ├── coeffbinint.m          # 系数整数化
│   ├── coeffint.m             # 系数整数转换
│   │
│   ├── dec2hex754.m           # 十进制→IEEE-754十六进制
│   ├── hex754_2dec.m          # IEEE-754十六进制→十进制
│   ├── dec2bin.m              # 十进制→二进制（支持小数）
│   ├── dec2bin754.m           # 十进制→IEEE-754二进制
│   ├── hex2bin.m              # 十六进制→二进制
│   ├── bin2dec.m              # 二进制→十进制
│   └── binaryVectorToHex.m   # 二进制向量→十六进制
│
└── 第4层: 工具函数
    └── compare_vector.m       # 向量比较
```

### 2.2 文件功能详解

#### 🔴 **核心文件**

##### `GoldenModel.m` - 主程序

```matlab
% 功能：完整的插值流程
% 1. 设置输入和选择函数
% 2. 执行范围缩减优化(RRO)
% 3. 加载查找表(LUT)
% 4. 提取尾数位进行分段
% 5. 计算二次多项式
% 6. 后处理得到最终结果
```

##### `coeff.m` - 系数库（2783行）

```matlab
% 存储10种函数的预计算系数
% 每个函数包含：
%   - C0d: 常数项系数数组
%   - C1d: 一次项系数数组
%   - C2d: 二次项系数数组
%   - t, p, q: 系数精度参数
%   - m: 分段参数（2^m段）
```

##### `loadLUTs.m` - 查找表加载器

```matlab
% 功能：
% 1. 调用coeff.m获取浮点系数
% 2. 转换为二进制表示
% 3. 提取公共前缀优化存储
% 4. 生成硬件可用的查找表
```

##### `getLUT.m` - 存储优化器

```matlab
% 功能：
% - 分析所有系数的公共前缀
% - 将公共部分提取为concat
% - 减少查找表存储需求
% 
% 例如：如果所有系数都以"01"开头
% → 只存储一次"01"，而非128次
```

#### 🟡 **数据转换文件**

##### IEEE-754格式转换

```matlab
dec2hex754(x)    % 十进制 → 十六进制 (如: 1.5 → '3FC00000')
hex754_2dec(h)   % 十六进制 → 十进制 (如: '3FC00000' → 1.5)
dec2bin754(x)    % 十进制 → 二进制IEEE-754
```

##### 通用进制转换

```matlab
dec2bin(x, nd)   % 十进制→二进制，支持小数点后nd位
bin2dec(b)       % 二进制→十进制，支持小数
hex2bin(h)       % 十六进制→二进制
binaryVectorToHex(v)  % 二进制向量→十六进制
```

---

## 3. 算法原理

### 3.1 核心思想（Python伪代码）

```python
def quadratic_approximation(x, function_type):
    """
    二次多项式分段插值
  
    将定义域[1,2)分成2^m段，每段用二次多项式逼近：
    f(x) ≈ C0 + C1·x + C2·x²
    """
  
    # 步骤1: 转换为IEEE-754格式
    ieee754 = float_to_ieee754(x)
  
    # 步骤2: 提取尾数（mantissa）
    # IEEE-754: [符号(1bit)][指数(8bit)][尾数(23bit)]
    mantissa = extract_mantissa(ieee754)
  
    # 步骤3: 分段索引
    # 用尾数的前m位确定段号
    segment = mantissa[0:m]  # 例如m=7，有128段
    x_interp = mantissa[m:]  # 剩余位作为插值变量
  
    # 步骤4: 查表获取系数
    C0 = LUT_C0[segment]  # 常数项
    C1 = LUT_C1[segment]  # 一次项
    C2 = LUT_C2[segment]  # 二次项
  
    # 步骤5: 计算多项式
    result = C0 + C1 * x_interp + C2 * x_interp**2
  
    # 步骤6: 后处理（根据函数类型调整指数）
    final = post_process(result, function_type, exponent)
  
    return final
```

### 3.2 数学原理

#### 分段思想

将定义域 [1, 2) 均匀分成 **2^m** 个小段：

- m=6 → 64段，每段宽度 ≈ 0.0156
- m=7 → 128段，每段宽度 ≈ 0.0078
- 段数越多，精度越高，但存储需求增加

#### 二次多项式逼近

在每个小段 [a, a+Δ] 内，用泰勒展开：

```
f(x) ≈ f(a) + f'(a)·(x-a) + f''(a)/2·(x-a)²
     = C0 + C1·Δx + C2·Δx²
```

其中：

- C0 = f(a) - 常数项
- C1 = f'(a) - 一次项系数
- C2 = f''(a)/2 - 二次项系数
- Δx = x - a - 归一化插值变量

### 3.3 范围缩减优化 (RRO)

某些函数需要预处理以归约到标准范围：

#### 指数函数 (2^x)# 将任意范围的x转换到[0,1)

#### 三角函数 (sin/cos)

```python
# 1. 周期归约: x → x mod 2π
# 2. 象限判断
# 3. 归约到第一象限[0, π/2]
# 4. 查表计算
# 5. 根据象限调整符号
```

---

## 4. 使用方法

### 4.1 运行MATLAB版本

#### 方式1: 修改主文件参数

```matlab
% 打开 GoldenModel.m
% 修改第5-7行：

input = dec2hex754(1.5);  % 输入值
% input = 'C23A36C1';     % 或直接用十六进制
func = 1;                  % 函数选择（见下表）

% 运行
GoldenModel
```

#### 方式2: 使用测试脚本

```matlab
% 运行简化测试
test_simple

% 运行详细测试（推荐）
test_detailed
```

#### 函数编号对照表

| 编号 | 函数              | 说明                 |
| ---- | ----------------- | -------------------- |
| 1    | `reci`          | 倒数 1/x             |
| 2    | `sqrt_1_2`      | 平方根（奇指数）     |
| 3    | `sqrt_2_4`      | 平方根（偶指数）     |
| 4    | `reci_sqrt_1_2` | 倒数平方根（奇指数） |
| 5    | `reci_sqrt_2_4` | 倒数平方根（偶指数） |
| 6    | `exp`           | 指数 2^x             |
| 7    | `ln2`           | 对数 log₂(x)        |
| 8    | `ln2e0`         | 对数（指数=0）       |
| 9    | `sin`           | 正弦                 |
| 10   | `cos`           | 余弦                 |

### 4.2 运行Python版本

```bash
# 直接运行演示
python golden_model_python.py

# 或在Python中导入
from golden_model_python import QuadraticInterpolator

# 创建插值器
interp = QuadraticInterpolator('reciprocal')

# 计算逼近值
result = interp.approximate(1.5, verbose=True)
print(f"1/1.5 ≈ {result}")
```

---

## 5. Python对照

### 5.1 语法对照

| MATLAB          | Python          | 说明                 |
| --------------- | --------------- | -------------------- |
| `strcat(a,b)` | `a + b`       | 字符串拼接           |
| `size(A,1)`   | `A.shape[0]`  | 获取行数             |
| `zeros(1,n)`  | `np.zeros(n)` | 创建零数组           |
| `bin2dec(s)`  | `int(s, 2)`   | 二进制转十进制       |
| `dec2bin(x)`  | `bin(x)[2:]`  | 十进制转二进制       |
| `floor(x)`    | `np.floor(x)` | 向下取整             |
| `A(1:3,:)`    | `A[0:3,:]`    | 数组切片（注意索引） |

### 5.2 关键概念对照

#### IEEE-754格式操作

**MATLAB:**

```matlab
% 转换为十六进制
hex_str = dec2hex754(1.5);  % → '3FC00000'

% 提取部分
bin_str = hex2bin(hex_str);
sign = bin_str(1);
exp = bin_str(2:9);
man = bin_str(10:end);
```

**Python:**

```python
import struct

# 转换为十六进制
packed = struct.pack('>f', 1.5)
hex_str = packed.hex().upper()  # → '3FC00000'

# 提取部分
int_val = int(hex_str, 16)
sign = (int_val >> 31) & 0x1
exp = (int_val >> 23) & 0xFF
man = int_val & 0x7FFFFF
```

#### 查找表操作

**MATLAB:**

```matlab
% 加载查找表
[LUTC0, LUTC1, LUTC2, m] = loadLUTs(func);

% 查表
segment = bin2dec(man(1:m)) + 1;  % MATLAB索引从1开始
C0 = LUTC0(segment, :);
```

**Python:**

```python
# 加载查找表
lut_c0, lut_c1, lut_c2, m = load_luts(func)

# 查表
segment = int(man[0:m], 2)  # Python索引从0开始
c0 = lut_c0[segment, :]
```

### 5.3 完整流程对照

| 步骤        | MATLAB                        | Python等价                     |
| ----------- | ----------------------------- | ------------------------------ |
| 1. 转换格式 | `dec2hex754(x)`             | `struct.pack('>f', x).hex()` |
| 2. 提取尾数 | `man = bin_str(10:end)`     | `man = int_val & 0x7FFFFF`   |
| 3. 段索引   | `seg = bin2dec(man(1:m))+1` | `seg = man >> (23-m)`        |
| 4. 查表     | `C0 = LUTC0(seg,:)`         | `c0 = lut_c0[seg,:]`         |
| 5. 计算     | `res = C0 + C1*x + C2*x^2`  | `res = c0 + c1*x + c2*x**2`  |

---

## 6. 测试结果示例

### 倒数函数 (1/x)

```
输入: x = 1.5
输出: 0.6666666865
真实值: 0.6666666667
绝对误差: 1.99e-08
相对误差: 0.000003%
```

### 平方根函数 (√x)

```
输入: x = 2.0
输出: 1.4142135382
真实值: 1.4142135624
绝对误差: 2.42e-08
相对误差: 0.000002%
```

### 倒数平方根 (1/√x)

```
输入: x = 4.0
输出: 0.5000000000
真实值: 0.5000000000
绝对误差: 0.00e+00
相对误差: 0.000000%
```

---

## 7. 关键参数调优

### m - 分段参数

```
m=6  → 64段   → 较小LUT，较低精度
m=7  → 128段  → 平衡选择（推荐）
m=8  → 256段  → 更高精度，更大LUT
```

### 精度参数 (t, p, q)

```
t: C0系数的位宽
p: C1系数的位宽
q: C2系数的位宽

典型值: t=26, p=16, q=10
```

---

## 8. 总结

### ✨ 优势

1. **硬件友好** - 只需ROM（查找表）+ 乘法器 + 加法器
2. **固定时延** - 无迭代，适合流水线
3. **精度可控** - 通过调整m平衡面积/精度
4. **易于扩展** - 添加新函数只需补充系数

### 🎯 适用场景

- FPGA/ASIC硬件加速器
- 嵌入式系统（资源受限）
- 实时信号处理
- 图形渲染管线

### 📚 进一步学习

- 泰勒级数与多项式逼近
- IEEE-754浮点数标准
- 查找表优化技术
- 范围缩减算法

---

**作者**: Golden Model 分析
**日期**: 2026-01-13
**版本**: 1.0
