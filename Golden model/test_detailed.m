

clear all;
clc;

fprintf('╔═══════════════════════════════════════════════════════════╗\n');
fprintf('║   分段二次多项式插值 - Golden Model 完整测试              ║\n');
fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');

% ===========================================================================
% 测试函数列表 - 只保留 1/x、2^x、log₂x
% ===========================================================================
test_cases = {
    % [函数编号, 输入值, 函数名称, 真实值计算函数]
    {1, 16384,  '倒数 1/x',   @(x) 1./x};
    {1, 3.312,   '倒数 1/x',   @(x) 1./x};
    {1, -1.234432,   '倒数 1/x',   @(x) 1./x};


    % {6, 2.5,     '指数 2^x',   @(x) 2.^x};
    % {6, -1.0,    '指数 2^x',   @(x) 2.^x};
    % {6, 0.5,     '指数 2^x',   @(x) 2.^x};
    % {6, 5.0,     '指数 2^x',   @(x) 2.^x};
    % {6, -3.0,    '指数 2^x',   @(x) 2.^x};

    {7, 30.2332,      '对数 log₂x', @(x) log2(x)};
    {7, 78.1232,     '对数 log₂x', @(x) log2(x)};
    {7, 0.23233,    '对数 log₂x', @(x) log2(x)}; 
};
% 测试函数列表 - 只保留 1/x、2^x、log₂x 
% 随机生成：为每个函数设定数值范围并抽样 
% 1/x 避免过近 0；2^x 控制在 [-6,6] 防止溢出；log₂x 取 (0.1, 256] 
% =========================================================================== 
rng(0);  % 固定随机种子以便复现 
 
% test_cases = {}; 
 
% % 1/x: 范围 [1, 16384] 内均匀随机
% n_reci = 8;
% reci_vals = 1 + (16384 - 1) * rand(1, n_reci);
% for v = reci_vals
%     test_cases{end+1} = {1, v, '倒数 1/x', @(x) 1./x}; %#ok<AGROW>
% end
 
% % 2^x: 控制范围 [-6, 6]
% % n_exp = 6; 
% % exp_vals = -6 + (6 - (-6)) * rand(1, n_exp); 
% % for v = exp_vals 
% %     test_cases{end+1} = {6, v, '指数 2^x', @(x) 2.^x}; %#ok<AGROW> 
% % end 
 
% % log₂x: 取 (0.1, 256] 
% n_log = 6; 
% log_vals = 0.1 + (256 - 0.1) * rand(1, n_log); 
% for v = log_vals 
%     test_cases{end+1} = {7, v, '对数 log₂x', @(x) log2(x)}; %#ok<AGROW> 
% end 

% ===========================================================================
% 执行测试
% ===========================================================================
for test_idx = 1:length(test_cases)
    test = test_cases{test_idx};
    func = test{1};
    input_val = test{2};
    func_name = test{3};
    true_func = test{4};
    
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('【测试 %d】 %s\n', test_idx, func_name);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('输入值: %.6f\n', input_val);
    
    % -----------------------------------------------------------------------
    % 步骤1: 转换为IEEE-754格式
    % -----------------------------------------------------------------------
    input = dec2hex754(input_val);
    input_original = input;  % 保存原始输入，用于后处理
    fprintf('\n[步骤1] IEEE-754格式转换\n');
    fprintf('  十六进制: %s\n', input);
    
    % -----------------------------------------------------------------------
    % 步骤2: 解析二进制表示
    % -----------------------------------------------------------------------
    number = char(hex2bin(input));
    s = number(1);              % 符号位
    exp = number(2:9);          % 指数位 (8位)
    man = number(10:end);       % 尾数位 (23位)
    
    fprintf('\n[步骤2] 二进制解析\n');
    fprintf('  完整二进制: %s\n', number);
    fprintf('  符号位 S: %s (%s)\n', s, char('正'*strcmp(s,'0') + '负'*strcmp(s,'1')));
    fprintf('  指数位 E: %s (实际指数: %d - 127 = %d)\n', ...
        exp, bin2dec(strcat(exp,'.0')), bin2dec(strcat(exp,'.0'))-127);
    fprintf('  尾数位 M: %s\n', man);
    
    % -----------------------------------------------------------------------
    % 步骤2.5: RRO处理 (仅用于func=6 指数函数)
    % -----------------------------------------------------------------------
    if func == 6
        fprintf('\n[步骤2.5] RRO预处理 (2^x专用)\n');
        if (bin2dec(strcat(exp,".0"))>133)
            fprintf('  指数过大，设置为无穷\n');
            man = strcat('1','11111111','00000000000000000000000');
            vec = 1:32;
            for i=1:length(man)
                vec(i)=man(i)-48;
            end
            input = binaryVectorToHex(vec);
        else
            man_rro = ['0' '0' '1' man char(zeros(1,6)+48)];
            shift = 133-bin2dec(strcat(exp,".0"));
            man_rro = [char(zeros(1,shift)+48) man_rro(1:end-shift)];
            
            % XOR with sign
            for i=1:length(man_rro)
                if man_rro(i)=='0' && s=='0'
                    man_rro(i)='0';
                elseif man_rro(i)=='0' && s=='1'
                    man_rro(i)='1';
                elseif man_rro(i)=='1' && s=='0'
                    man_rro(i)='1';
                else
                    man_rro(i)='0';
                end
            end
            
            man_rro = bin2dec([man_rro '.0'])+bin2dec([s '.0']);
            man_rro = dec2bin(man_rro,0);
            
            if (length(man_rro))~=32
                man_rro = [char(zeros(1,32-length(man_rro))+48) man_rro];
            end
            
            man_rro = ['0' man_rro(2:end)];
            
            vec = 1:32;
            for i=1:length(man_rro)
                vec(i)=man_rro(i)-48;
            end
            
            input = binaryVectorToHex(vec);
            fprintf('  RRO后输入: %s\n', input);
        end
        
        % 重新解析RRO后的input
        number = char(hex2bin(input));
        s = number(1);
        exp = number(2:9);
        man = number(10:end);
        fprintf('  RRO后尾数: %s\n', man);
    end
    
    % -----------------------------------------------------------------------
    % 步骤3: 加载查找表
    % -----------------------------------------------------------------------
    func_act = func;
    
    % 仅保留 1/x, 2^x, log2 三种函数
    [LUTC0, LUTC1, LUTC2, m] = loadLUTs(func);
    lut_name = '标准LUT (仅1/x,2^x,log2)';
    
    fprintf('\n[步骤3] 加载查找表\n');
    fprintf('  LUT类型: %s\n', lut_name);
    fprintf('  分段参数 m: %d\n', m);
    fprintf('  分段总数: 2^%d = %d 段\n', m, 2^m);
    fprintf('  查找表尺寸:\n');
    fprintf('    - LUT_C0: %d × %d 位\n', size(LUTC0, 1), size(LUTC0, 2));
    fprintf('    - LUT_C1: %d × %d 位\n', size(LUTC1, 1), size(LUTC1, 2));
    fprintf('    - LUT_C2: %d × %d 位\n', size(LUTC2, 1), size(LUTC2, 2));
    
    % -----------------------------------------------------------------------
    % 步骤4: 计算段索引和插值变量
    % -----------------------------------------------------------------------
    % x1: 段索引 (用尾数的前m位确定)
    % x2: 插值变量 (用尾数的剩余位确定)
    x1 = bin2dec(strcat(man(1:m),'.0')) + 1;  % MATLAB索引从1开始
    x2 = floor(bin2dec(strcat('0.',char(zeros(1,m)+48),man(m+1:end))) * 2^23);
    
    fprintf('\n[步骤4] 分段与插值变量计算\n');
    fprintf('  尾数前%d位: %s → 段索引 x1 = %d\n', m, man(1:m), x1);
    fprintf('  尾数后%d位: %s → 插值变量 x2 = %d\n', 23-m, man(m+1:end), x2);
    
    % -----------------------------------------------------------------------
    % 步骤5: 从查找表中获取系数
    % -----------------------------------------------------------------------
    C0 = LUTC0(x1,:);
    C1 = LUTC1(x1,:);
    C2 = LUTC2(x1,:);
    
    fprintf('\n[步骤5] 查找表系数提取\n');
    fprintf('  C0[%d]: %s (符号: %s)\n', x1, C0(2:end), C0(1));
    fprintf('  C1[%d]: %s (符号: %s)\n', x1, C1(2:end), C1(1));
    fprintf('  C2[%d]: %s (符号: %s)\n', x1, C2(2:end), C2(1));
    
    % -----------------------------------------------------------------------
    % 步骤6: 二次多项式计算
    % -----------------------------------------------------------------------
    % 公式: result = C0 + C1·x + C2·x²
    sign = [1 -1];
    term0 = bin2dec(strcat(C0(2:end),'.0')) * 2^14 * sign(str2double(C0(1))+1);
    term1 = bin2dec(strcat(C1(2:end),'.0')) * x2 * sign(str2double(C1(1))+1);
    term2 = (bin2dec(strcat(C2(2:end),'.0')) * floor(((bin2dec(strcat(man(m+1:end),'.0'))^2) * 2^-19))) * 2^1 * sign(str2double(C2(1))+1);
    
    operation = term0 + term1 + term2;
    
    fprintf('\n[步骤6] 二次多项式插值计算\n');
    fprintf('  f(x) ≈ C0 + C1·x + C2·x²\n');
    fprintf('  C0项: %e\n', term0);
    fprintf('  C1·x项: %e\n', term1);
    fprintf('  C2·x²项: %e\n', term2);
    fprintf('  总和: %e\n', operation);
    
    % -----------------------------------------------------------------------
    % 步骤7: 结果后处理（根据函数类型调整指数）
    % -----------------------------------------------------------------------
    if func == 1  % 倒数
        res = dec2hex754((operation * 2^-41) * (2^-(bin2dec(strcat(exp,'.0'))-127)) * sign(str2double(s)+1));
        post_process_desc = '乘以 2^(-指数)';
    elseif func == 6  % 2^x
        % 指数函数：需要从原始input重新计算exp值
        aux = char(hex2bin(input_original));
        if aux(2) == '1'
            % 负指数处理
            aux_bits = aux(2:9);
            for i=1:length(aux_bits)
                if aux_bits(i) == '0'
                    aux_bits(i) = '1';
                else
                    aux_bits(i) = '0';
                end
            end
            exp_val = (bin2dec(strcat(aux_bits,'.0'))+1)*-1;
        else
            exp_val = bin2dec(strcat(aux(2:9),'.0'));
        end
        res = dec2hex754((operation * 2^-41) * (2^(exp_val)));
        post_process_desc = sprintf('乘以 2^(%d)', exp_val);
    elseif func == 7  % log₂x
        if func_act == 8
            res = dec2hex754((operation * 2^-41) * (hex754_2dec(input)-1));
            post_process_desc = '乘以 (input-1)';
        else
            res = dec2hex754((operation * 2^-41) + (bin2dec(strcat(exp,'.0'))-127));
            post_process_desc = '加上 (指数-127)';
        end
    end
    
    fprintf('\n[步骤7] 后处理\n');
    fprintf('  操作: %s\n', post_process_desc);
    
    % -----------------------------------------------------------------------
    % 结果比较
    % -----------------------------------------------------------------------
    approx_result = hex754_2dec(res);
    true_result = true_func(input_val);
    error = abs(approx_result - true_result);
    
    ulp_error = calculateULP(approx_result, true_result);
    
    fprintf('\n╔═══════════════════════════════════════════════════════════╗\n');
    fprintf('║                        最终结果                            ║\n');
    fprintf('╠═══════════════════════════════════════════════════════════╣\n');
    fprintf('║  输出 (HEX):  %-43s  ║\n', res);
    fprintf('║  输出 (DEC):  %-43.10f  ║\n', approx_result);
    fprintf('║  真实值:      %-43.10f  ║\n', true_result);
    fprintf('║  绝对误差:    %-43e  ║\n', error);
    
    fprintf('║  ULP误差:     %-43.2f  ║\n', ulp_error);
    fprintf('╚═══════════════════════════════════════════════════════════╝\n\n');
end

fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('所有测试完成！\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
