function ulp_error = calculateULP(approx, exact)
    % 计算两个浮点数之间的ULP误差
    % ULP (Units in the Last Place) 是浮点数精度的标准度量
    %
    % 参数:
    %   approx - 逼近值
    %   exact  - 精确值
    %
    % 返回:
    %   ulp_error - ULP误差值
    
    % 处理特殊情况
    if isnan(approx) || isnan(exact)
        ulp_error = NaN;
        return;
    end
    
    if isinf(approx) || isinf(exact)
        ulp_error = Inf;
        return;
    end
    
    if exact == 0
        ulp_error = abs(approx);
        return;
    end
    
    % 转换为IEEE-754十六进制
    exact_hex = dec2hex754(exact);
    approx_hex = dec2hex754(approx);
    
    % 转换为二进制字符串
    exact_bin = char(hex2bin(exact_hex));
    approx_bin = char(hex2bin(approx_hex));
    
    % 检查符号位
    if exact_bin(1) ~= approx_bin(1)
        % 符号不同，使用相对误差估算
        ulp_error = abs(approx - exact) / eps(single(exact));
        return;
    end
    
    % 将二进制表示转换为无符号整数
    % 对于正数：直接使用二进制整数值
    % 对于负数：需要用补码表示
    % 手动将32位二进制字符串转为整数
    exact_uint = 0;
    approx_uint = 0;
    for i = 1:32
        exact_uint = exact_uint * 2 + (exact_bin(i) - '0');
        approx_uint = approx_uint * 2 + (approx_bin(i) - '0');
    end
    
    % 如果是负数，需要转换为有序表示（二补数映射）
    if exact_bin(1) == '1'
        % 负数：翻转所有位后的值
        exact_uint = 2^32 - 1 - exact_uint;
        approx_uint = 2^32 - 1 - approx_uint;
    end
    
    % ULP误差就是两个整数表示的差值
    ulp_error = abs(double(approx_uint) - double(exact_uint));
end
