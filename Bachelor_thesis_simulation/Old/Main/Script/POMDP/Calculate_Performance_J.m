function J = Calculate_Performance_J(ts_yj, t_start, t_end)
    % Calculate_Performance_J: 从性能输出时间体 yj 中提取稳态期望代价 J
    % 输入:
    %   ts_yj   - MATLAB timeseries 对象。可以是多维的 yj，也可以是已算好的 1 维 ||yj||^2。
    %   t_start - (可选) 计算均值的起始时间 (秒)。如果不填，默认取数据的后半段(50%)来近似稳态。
    %   t_end   - (可选) 计算均值的结束时间 (秒)。如果不填，默认取到仿真结束。
    % 输出:
    %   J       - 标量，系统在指定时间段内的平均性能损失 (对应 J0a 或 J1a)

    % 1. 提取时间和数据，消除多余维度
    t = squeeze(ts_yj.Time);
    data = squeeze(ts_yj.Data);

    % 2. 自动处理维度并计算 ||yj(k)||^2
    [d1, d2] = size(data);
    num_points = length(t);

    if d1 == num_points && d2 == 1
        % 已经是 1 维列向量，假设传入的就是 ||yj||^2 或者单变量误差
        norm_sq = data;
    elseif d2 == num_points && d1 == 1
        % 已经是 1 维行向量
        norm_sq = data';
    elseif d1 == num_points
        % 格式 [时间点 x 通道]，对行求平方和
        norm_sq = sum(data.^2, 2);
    elseif d2 == num_points
        % 格式 [通道 x 时间点]，对列求平方和
        norm_sq = sum(data.^2, 1)';
    else
        error('数据维度解析失败：数据矩阵的任何一个维度都与时间轴长度不符。');
    end

    % 3. 处理时间窗参数 (提取稳态段)
    if nargin < 3 || isempty(t_end)
        t_end = t(end);
    end
    if nargin < 2 || isempty(t_start)
        % 如果没有给出起始时间，默认扔掉前半段的瞬态，只取后 50% 计算稳态期望
        t_start = t(1) + (t(end) - t(1)) / 2; 
    end

    % 4. 提取指定时间窗内的数据
    idx = (t >= t_start) & (t <= t_end);

    if ~any(idx)
        warning('指定的时间区间 [%.2f, %.2f] 内没有数据点，将返回 NaN。', t_start, t_end);
        J = NaN;
        return;
    end

    valid_norm_sq = norm_sq(idx);

    % 5. 计算数学期望 (即均值)
    J = mean(valid_norm_sq);

    % --- 打印结果信息，方便在命令行核对 ---
    fprintf('--- 性能代价期望 J 计算完成 ---\n');
    fprintf('计算时间窗: [%.2f s, %.2f s]\n', t_start, t_end);
    fprintf('参与计算的采样点数: %d\n', sum(idx));
    fprintf('最终统计常数 J = %.4e\n', J);
    fprintf('-------------------------------\n');
end