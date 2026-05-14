function ts_out = Calculate_energy(ts_in)
    % Calculate_Residual_Norm_Sq: 计算输入时间体数据的模长平方 (r1^2 + r2^2 + ...)
    % 输入: 
    %   ts_in - MATLAB timeseries 对象 (包含多维残差信号)
    % 输出: 
    %   ts_out - 仅包含一维模长平方数据的 timeseries 对象，保持原始时间轴
    
    % 1. 提取原始数据和时间轴
    data_raw = ts_in.Data;
    t = ts_in.Time;
    
    % 2. 使用 squeeze 处理维度
    % Simulink 导出的数据常带有冗余维度 (例如 1x2x350)
    % squeeze 后通常变为 [Channels x Time] 或 [Time x Channels]
    data = squeeze(data_raw);
    
    % 3. 确定通道维度并计算平方和
    [d1, d2] = size(data);
    num_time_points = length(t);
    
    if d1 == num_time_points
        % 格式 A: [时间点 x 通道]
        % 对每一行（每个时刻）的所有列（通道）求平方和
        norm_sq = sum(data.^2, 2);
    elseif d2 == num_time_points
        % 格式 B: [通道 x 时间点]
        % 对每一列（每个时刻）的所有行（通道）求平方和，并确保结果为列向量
        norm_sq = sum(data.^2, 1)';
    else
        error('维度不匹配：数据矩阵的任何一个维度都与时间轴长度不符。');
    end
    
    % 4. 封装为新的 timeseries 对象
    ts_out = timeseries(norm_sq, t);
    
    % 5. 设置属性，方便后续绘图
    ts_out.Name = [ts_in.Name, '_SquaredNorm'];
    
    % 打印处理结果
    % fprintf('--- 残差模长平方计算完成 ---\n');
    % fprintf('原始信号通道数: %d\n', min(d1, d2));
    % fprintf('采样点总数: %d\n', num_time_points);
    % fprintf('---------------------------\n');
end