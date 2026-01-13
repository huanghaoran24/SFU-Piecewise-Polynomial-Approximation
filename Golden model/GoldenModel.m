% -------------------------------------------------------------------------
% Set the input value and select the function
% -------------------------------------------------------------------------
% 说明：可以直接给出十进制输入（使用 dec2hex754 转换为 IEEE-754 HEX），
% 或者直接指定 IEEE-754 的 8 字符十六进制字符串（如 'C23A36C1'）。
% 函数编号映射：
% 1: reci (1/x)
% 2: sqrt_1_2 (sqrt for [1,2))
% 3: sqrt_2_4 (sqrt for [2,4))
% 4: reci_sqrt_1_2 (1/sqrt for [1,2))
% 5: reci_sqrt_2_4 (1/sqrt for [2,4))
% 6: exp (2^x)
% 7: ln2 (log2)
% 8: ln2e0
% 9: sin
% 10: cos

% input必须是8位十六进制字符串
% input = dec2hex754(16384);   % Input in decimal format,
% input = 'C23A36C1';      % Input in IEEE-754 format
input = dec2hex754(-3);   % Input in decimal format,
func = 6;

% -------------------------------------------------------------------------
func_act = func;
func_rro = func;

functions = [   "reci",...          -- 1
                "sqrt_1_2",...      -- 2
                "sqrt_2_4",...      --
                "reci_sqrt_1_2",... -- 4
                "reci_sqrt_2_4",... --
                "exp",...           -- 6
                "ln2",...           -- 7
                "ln2e0",...         --
                "sin"...            -- 9
                "cos"]...           -- 10
                ;
[LUTC0,LUTC1,LUTC2,m] = loadLUTs(func);

% -------------------------------------------------------------------------
% RRO (Range Reduction & Optimization)
% -------------------------------------------------------------------------
% 对于某些函数（如 2^x、sin/cos）需要先做范围缩减（RRO），
% 将任意输入归约到查表的标准区间，从而使用查找表 + 二次插值。
% 这里先处理指数函数 2^x 的专门格式。
if (func == 6)                    % If function is 2^x
    % 将十六进制转换为二进制字符串形式（'s eeeeeeee mmmmm...')
    input = char(hex2bin(input));

    % 符号位 s，指数 exp（8位），尾数 man（23位，无隐含1）
    s = input(1);
    exp = input(2:9);
    man = input(10:end);

    % Too big exponent
    if (bin2dec(strcat(exp,".0"))>133)
        man = strcat('1','11111111','00000000000000000000000');

        vec = 1:32;
        for i=1:size(man,2)
            vec(i)=man(i)-48;
        end

        input = binaryVectorToHex(vec);
    else
        man = strcat("001",man,char(zeros(1,6)+48));
        man = strcat(char(zeros(1,133-bin2dec(strcat(exp,".0")))+48),man(1:end-(133-bin2dec(strcat(exp,".0")))));

        % XOR
        for i=1:size(man,2)
            if man(i)=='0' && s=='0'
                man(i)='0';
            elseif man(i)=='0' && s=='1'
                man(i)='1';
            elseif man(i)=='1' && s=='0'
                man(i)='1';
            else
                man(i)='0';
            end
        end

        man = bin2dec(strcat(man,'.0'))+bin2dec(strcat(s,".0"));
        man = dec2bin(man,0);

        if (size(man,2))~=32
            man = strcat(char(zeros(1,32-size(man,2))+48),man);
        end

        man = strcat('0',man(2:end));

        vec = 1:32;
        for i=1:size(man,2)
            vec(i)=man(i)-48;
        end

        input = binaryVectorToHex(vec);
    end
elseif (func == 9 || func == 10)                    % If function is sin/cos
        % 三角函数：先把 IEEE-754 HEX 转为十进制浮点数，方便做周期/象限归约
        input = hex754_2dec(input);

        % 保存原始符号，后面根据象限调整
        if (input>0)
            s = '0';
        else
                input = input*-1;
                s = '1';
        end

    % Vueltas
    if (input > pi()*2)
        vueltas = floor(input/(pi()*2));
        input = input-(pi()*2*vueltas);
    end

    % Cuadrante
    if (input>0 && input<=(pi()/2))
        Q='00';
    elseif(input>pi()/2 && input<=pi())
        Q='01';
    elseif(input>pi() && input<=((3*pi())/2))
        Q='10';
    else
        Q='11';
    end

    % Reducción al primer cuadrante
    if (Q=="01")
        input=input-(pi()/2);
	  elseif (Q=="10")
        input=input-pi();
    elseif (Q=="11")
        input=input-((3*pi())/2);
    end

    input=erase(dec2bin(input,23),'.');
    input=strcat(s,Q,'00000',input);

    vec = 1:32;
    for i=1:size(input,2)
        vec(i)=input(i)-48;
    end

    input = binaryVectorToHex(vec);
end

% -------------------------------------------------------------------------
% Adjust the LUTs
% -------------------------------------------------------------------------
% 根据输入的范围/格式选择合适的查找表（例如 sqrt 有两套 LUT 对应不同指数奇偶性）
if func == 2                                    % For function srqt
    aux = char(hex2bin(input));
    if aux(9) == '0' && func_act == 2           % If the exponent is even (range 2-4)
        [LUTC0,LUTC1,LUTC2,m] = loadLUTs(3);
        func_act = 3;
    elseif aux(9) == '1' && func_act == 3       % If the exponent is odd (range 1-2)
        [LUTC0,LUTC1,LUTC2,m] = loadLUTs(2);
        func_act = 2;
    end
elseif func == 4                                % For function 1/srqt
    aux = char(hex2bin(input));
    if aux(9) == '0' && func_act == 4           % If the exponent is even (range 2-4)
        [LUTC0,LUTC1,LUTC2,m] = loadLUTs(5);
        func_act = 5;
    elseif aux(9) == '1' && func_act == 5       % If the exponent is odd (range 1-2)
        [LUTC0,LUTC1,LUTC2,m] = loadLUTs(4);
        func_act = 4;
    end
elseif func == 7                                % For function log2
    aux = char(hex2bin(input));
    aux = bin2dec(strcat(aux(2:9),'.0'))-127;
    if aux == 0 && func_act == 7
        [LUTC0,LUTC1,LUTC2,m] = loadLUTs(8);
        func_act = 8;
    elseif aux ~= 0 && func_act == 8
        [LUTC0,LUTC1,LUTC2,m] = loadLUTs(7);
        func_act = 7;
    end
elseif func == 9                                % For function sin
    aux = char(hex2bin(input));
    % Adjust according to the RRO format
    if  (aux(1) == '0' && aux(2) == '0' && aux(3) == '1') ||...
        (aux(1) == '0' && aux(2) == '1' && aux(3) == '1') ||...
        (aux(1) == '1' && aux(2) == '0' && aux(3) == '1') ||...
        (aux(1) == '1' && aux(2) == '1' && aux(3) == '1')
        func_rro = 10;
    else
        func_rro = 9;
    end

    % Adjust according to the number
    if func_rro == 9
        aux = bin2dec(strcat(aux(9),'.',aux(10:end)));
        if aux>=1 && func_act == 9
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(10);
            func_act = 10;
        elseif aux<1 && func_act == 10
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(9);
            func_act = 9;
        end
    elseif func_rro == 10
        aux = bin2dec(strcat(aux(9),'.',aux(10:end)));
        if aux>=1 && func_act == 10
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(9);
            func_act = 9;
        elseif aux<1 && func_act == 9
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(10);
            func_act = 10;
        end
    end
elseif func == 10                               % For function cos
    aux = char(hex2bin(input));
    % Adjust according to the RRO format
    if  (aux(1) == '0' && aux(2) == '0' && aux(3) == '1') ||...
        (aux(1) == '0' && aux(2) == '1' && aux(3) == '1') ||...
        (aux(1) == '1' && aux(2) == '0' && aux(3) == '1') ||...
        (aux(1) == '1' && aux(2) == '1' && aux(3) == '1')
        func_rro = 9;
    else
        func_rro = 10;
    end

    % Adjust according to the number
    if func_rro == 10
        aux = bin2dec(strcat(aux(9),'.',aux(10:end)));
        if aux>=1 && func_act == 10
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(9);
            func_act = 9;
        elseif aux<1 && func_act == 9
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(10);
            func_act = 10;
        end
    elseif func_rro == 9
        aux = bin2dec(strcat(aux(9),'.',aux(10:end)));
        if aux>=1 && func_act == 9
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(10);
            func_act = 10;
        elseif aux<1 && func_act == 10
            [LUTC0,LUTC1,LUTC2,m] = loadLUTs(9);
            func_act = 9;
        end
    end
end

% -------------------------------------------------------------------------
% Adjust the number (prepare mantissa and sign for LUT lookup)
% -------------------------------------------------------------------------
% 把输入解析为尾数(man)、符号(s)、指数(exp)，并根据函数类型进行必要的调整
if func == 6                        % For function 2^x
    aux = char(hex2bin(input));
    % 对于 2^x，我们只需要尾数部分作为插值输入（23 位）
    man = aux(10:end);
elseif func == 9                    % For function sin
    aux = char(hex2bin(input));
    % Adjust the sign according to the RRO format
    if  (aux(1) == '0' && aux(2) == '1' && aux(3) == '0') ||...
        (aux(1) == '0' && aux(2) == '1' && aux(3) == '1') ||...
        (aux(1) == '1' && aux(2) == '0' && aux(3) == '0') ||...
        (aux(1) == '1' && aux(2) == '0' && aux(3) == '1')
        s = '1';
    else
        s = '0';
    end

    aux = bin2dec(strcat(aux(9),'.',aux(10:end)));
    if aux>=1
        Pi_2 = bin2dec('110010010000111111011011.0');   %PI/2 truncated at 23 bits

        man = char(hex2bin(input));
        man = man(9:end);
        man = bin2dec(strcat(man,'.0'));

        man = Pi_2-man;
        man = dec2bin(man,0);
        man = strcat(char(zeros(1,23-size(man,2))+48),man);
    else
        man = char(hex2bin(input));
        man = man(10:end);
    end
elseif func == 10                   % For function cos
	aux = char(hex2bin(input));
    % Adjust the sign according to the RRO format
    if  (aux(1) == '0' && aux(2) == '0' && aux(3) == '1') ||...
        (aux(1) == '0' && aux(2) == '1' && aux(3) == '0') ||...
        (aux(1) == '1' && aux(2) == '0' && aux(3) == '1') ||...
        (aux(1) == '1' && aux(2) == '1' && aux(3) == '0')
        s = '1';
	else
        s = '0';
    end

    aux = bin2dec(strcat(aux(9),'.',aux(10:end)));
    if aux>=1
        Pi_2 = bin2dec('110010010000111111011011.0');   %PI/2 truncated at 23 bits

        man = char(hex2bin(input));
        man = man(9:end);
        man = bin2dec(strcat(man,'.0'));

        man = Pi_2-man;
        man = dec2bin(man,0);
        man = strcat(char(zeros(1,23-size(man,2))+48),man);
    else
        man = char(hex2bin(input));
        man = man(10:end);
    end
else
    % 默认情况（其它函数）：直接从 IEEE-754 中提取各部分
    number = char(hex2bin(input));
    s = number(1);
    exp = number(2:9);
    man = number(10:end);
    % 在后续阶段，man 的前 m 位决定哪一段 (segment index)，
    % 后续位用于插值变量（x2）。保持 man 为字符串，便于按位操作。
    
end


% -------------------------------------------------------------------------
% Evaluate the LUTs
% -------------------------------------------------------------------------
% 段索引 x1：使用尾数的前 m 位决定属于哪一段（MATLAB 索引从 1 起）
% 插值变量 x2：尾数的剩余位拼接为小数后乘以 2^23 得到整数形式用于乘法项
x1 = bin2dec(strcat(man(1:m),'.0'))+1;
x2 = floor(bin2dec(strcat('0.',char(zeros(1,m)+48),man(m+1:end)))*2^23);

% Get the value from the bus of LUTs
C0 = LUTC0(x1,:);
C1 = LUTC1(x1,:);
C2 = LUTC2(x1,:);

sign = [1 -1];
operation = bin2dec(strcat(C0(2:end),'.0'))*2^14*sign(str2double(C0(1))+1)+...
            bin2dec(strcat(C1(2:end),'.0'))*x2*sign(str2double(C1(1))+1)+...
            (bin2dec(strcat(C2(2:end),'.0'))*floor(((bin2dec(strcat(man(m+1:end),'.0'))^2)*2^-19)))*2^1*sign(str2double(C2(1))+1);

% -------------------------------------------------------------------------
% Adjust the result
% -------------------------------------------------------------------------
% 插值计算得到的 'operation' 是固定点格式的累加结果，需要
% 按照比例因子（2^-41 等）和输入的指数/符号进行缩放，恢复为浮点数
if func == 1                        % If function is reci
    % 1/x: 需根据原始输入指数做乘/除缩放并考虑符号
    res = dec2hex754((operation*2^-41)*(2^-(bin2dec(strcat(exp,'.0'))-127))*sign(str2double(s)+1));
    %res = dec2hex754((operation)*(2^-(bin2dec(strcat(exp,'.0'))-127))*sign(str2double(s)+1));
elseif func == 2                    % If function is sqrt
    if func_act == 2
        res = dec2hex754((operation*2^-41)*(2^((bin2dec(strcat(exp,'.0'))-127)/2)));
    else
        res = dec2hex754((operation*2^-41)*(2^((bin2dec(strcat(exp,'.0'))-127-1)/2)));
    end
elseif func == 4                    % If function is 1/sqrt
    if func_act == 4
        res = dec2hex754((operation*2^-41)*(2^-((bin2dec(strcat(exp,'.0'))-127)/2)));
    else
        res = dec2hex754((operation*2^-41)*(2^-((bin2dec(strcat(exp,'.0'))-127-1)/2)));
    end
elseif func == 6                    % If function is 2^x
    % 指数函数特殊处理：根据输入指数位决定最终乘以 2^exp
    aux = char(hex2bin(input));
    if aux(2) == '1'
        % 处理负指数（使用二补码风格翻转并求负）
        aux = aux(2:9);
        for i=1:length(aux)
            if aux(i) == '0'
                aux(i) = '1';
            else
                aux(i) = '0';
            end
        end
        exp = (bin2dec(strcat(aux,'.0'))+1)*-1;
    else
        exp = bin2dec(strcat(aux(2:9),'.0'));
    end
    % 最终结果 = 插值结果 * 2^exp
    res = dec2hex754((operation*2^-41)*(2^(exp)));
elseif func == 7    % If function is log2
    if func_act == 8
        res = dec2hex754((operation*2^-41)*(hex754_2dec(input)-1));
	else
        res = dec2hex754((operation*2^-41)+(bin2dec(strcat(exp,'.0'))-127));
    end
elseif func == 9 || func == 10      % For function sin or cos
    res = dec2hex754(operation*2^-41*sign(str2double(s)+1));
end

% -------------------------------------------------------------------------
% Exceptions
% -------------------------------------------------------------------------
% 处理特殊输入（如 subnormal，Inf/NaN）以及 2^x 的符号/边界情形
if func == 6                        % For function 2^x
    input = char(hex2bin(input));

    s = input(1);
    exp = input(2:9);
    man = input(10:end);

    % 负数且指数为 0 -> 0（范围外，返回 0）
    if (s=='1' && exp=="00000000")
        % 返回 +0（32 位全 0）
        res=binaryVectorToHex([0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]);
    % 负数且指数全1 -> NaN/Inf 直接构造输出
    elseif (s=='1' && exp=="11111111")
        res=strcat('0',exp,man);

        vec = 1:32;
        for i=1:length(res)
            vec(i)=res(i)-48;
        end

        res = binaryVectorToHex(vec);
    end
end
disp(res)
disp(hex754_2dec(res))
