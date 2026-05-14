function [Total_Sum, Average_Value] = Calculate_Signal_Stats(ts_data, t_start, t_end)
    % Calculate_Signal_Stats: 从时间序列中提取指定时间窗内的累积总和(能量)与平均值(期望)
    % 输入:
    %   ts_data - MATLAB timeseries 对象。可以是多维攻击信号 a(k)，也可以是性能输出 yj(k)。
    %   t_start - (可选) 计算的起始时间 (秒)。如果不填，默认从数据最起始点开始。
    %   t_end   - (可选) 计算的结束时间 (秒)。如果不填，默认取到仿真结束。
    % 输出:
    %   Total_Sum     - 标量，时间窗内平方范数的累积和 (常用于计算截断攻击能量 \epsilon_a)
    %   Average_Value - 标量，时间窗内平方范数的平均值 (常用于计算稳态性能损失期望 J)

    % 1. 提取时间和数据，消除多余维度
    t = squeeze(ts_data.Time);
    data = squeeze(ts_data.Data);

    % 2. 自动处理维度并计算每个时刻的 ||data(k)||^2
    [d1, d2] = size(data);
    num_points = length(t);

    if d1 == num_points && d2 == 1
        % 已经是 1 维列向量，假设传入的就是 ||data||^2 或者单变量
        norm_sq = data;
    elseif d2 == num_points && d1 == 1
        % 已经是 1 维行向量
        norm_sq = data';
    elseif d1 == num_points
        % 格式 [时间点 x 通道]，对行求平方和 (即计算各通道平方的总和)
        norm_sq = sum(data.^2, 2);
    elseif d2 == num_points
        % 格式 [通道 x 时间点]，对列求平方和
        norm_sq = sum(data.^2, 1)';
    else
        error('数据维度解析失败：数据矩阵的任何一个维度都与时间轴长度不符。');
    end

    % 3. 处理时间窗参数
    if nargin < 3 || isempty(t_end)
        t_end = t(end);
    end
    if nargin < 2 || isempty(t_start)
        % 【关键修改】：计算能量通常从头开始，故默认起点设为时间轴起点
        t_start = t(1); 
    end

    % 4. 提取指定时间窗内的数据
    idx = (t >= t_start) & (t <= t_end);

    if ~any(idx)
        warning('指定的时间区间 [%.2f, %.2f] 内没有数据点，将返回 NaN。', t_start, t_end);
        Total_Sum = NaN;
        Average_Value = NaN;
        return;
    end

    valid_norm_sq = norm_sq(idx);

    % 5. 计算数学统计值
    Total_Sum = sum(valid_norm_sq);      % 计算累积总和 (即能量)
    Average_Value = mean(valid_norm_sq); % 计算数学期望 (即均值/平均功率)

    % --- 打印结果信息，方便在命令行核对 ---
    fprintf('--- 信号统计值计算完成 ---\n');
    fprintf('计算时间窗: [%.2f s, %.2f s]\n', t_start, t_end);
    fprintf('参与计算的采样点数: %d\n', sum(idx));
    fprintf('累积总和 (Total Sum / Energy)   = %.4e\n', Total_Sum);
    fprintf('时间平均 (Average Value / Mean) = %.4e\n', Average_Value);
    fprintf('-------------------------------\n');
end