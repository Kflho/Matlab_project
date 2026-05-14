function [DetRate, FalseAlarmRate, MissRate] = Calculate_DetectionMetrics(ts_data, epsilon, attack_start, attack_end)
% Calculate_DetectionMetrics: 从残差能量时序中统计检测性能指标
%   基于阈值 epsilon 和攻击发生的时间段，计算：
%     检测率 (Detection Rate)   = TP / (TP+FN)
%     误报率 (False Alarm Rate) = FP / (FP+TN)
%     漏报率 (Miss Rate)        = FN / (TP+FN) = 1 - DetRate
%
% 输入:
%   ts_data      - MATLAB timeseries 对象，通常为残差模平方 |r(k)|^2 的时间序列
%   epsilon      - 标量，残差能量检测阈值
%   attack_start - 攻击开始时间 (秒)，可为标量或向量 (多段攻击)
%   attack_end   - 攻击结束时间 (秒)，与 attack_start 长度相同
%
% 输出:
%   DetRate        - 标量，检测率 (0~1)
%   FalseAlarmRate - 标量，误报率 (0~1)
%   MissRate       - 标量，漏报率 (0~1)
%
% 示例:
%   [Pd, Pf, Pm] = Calculate_DetectionMetrics(r2, 0.1043, 250, 1000);
%   % 单段攻击：250s~1000s
%
%   [Pd, Pf, Pm] = Calculate_DetectionMetrics(r2, 0.1043, [250, 1500], [750, 2000]);
%   % 两段攻击：250~750s 和 1500~2000s

    % 1. 提取时间与数据
    t = squeeze(ts_data.Time);
    data = squeeze(ts_data.Data);

    % 2. 自动获取残差能量序列（已为模平方则直接使用，否则计算向量范数平方）
    [d1, d2] = size(data);
    num_points = length(t);
    if d1 == num_points && d2 == 1
        norm_sq = data;                          % 已是标量序列
    elseif d2 == num_points && d1 == 1
        norm_sq = data';
    elseif d1 == num_points
        norm_sq = sum(data.^2, 2);               % 多维信号 → 各时刻平方和
    elseif d2 == num_points
        norm_sq = sum(data.^2, 1)';
    else
        error('数据维度与时间轴长度不符，无法自动解析。');
    end

    % 3. 构造攻击标志向量（逻辑数组）
    is_attack = false(num_points, 1);
    for k = 1:length(attack_start)
        is_attack = is_attack | ( (t >= attack_start(k)) & (t <= attack_end(k)) );
    end

    % 4. 阈值比较
    hit = (norm_sq > epsilon);

    % 5. 计算四类基本计数
    TP = sum( hit &  is_attack);    % 攻击时段内正确报警
    FN = sum(~hit &  is_attack);    % 攻击时段内漏报
    FP = sum( hit & ~is_attack);    % 正常时段内误报
    TN = sum(~hit & ~is_attack);    % 正常时段内正确静默

    % 6. 计算三个率
    if (TP + FN) == 0
        warning('攻击时间窗内无有效采样点，无法计算检测率和漏报率。');
        DetRate = NaN;
        MissRate = NaN;
    else
        DetRate = TP / (TP + FN);
        MissRate = FN / (TP + FN);        % = 1 - DetRate
    end

    if (FP + TN) == 0
        warning('正常时间窗内无有效采样点，无法计算误报率。');
        FalseAlarmRate = NaN;
    else
        FalseAlarmRate = FP / (FP + TN);
    end

    % 7. 打印详细结果
    fprintf('\n========= 检测性能指标报告 =========\n');
    fprintf('残差能量阈值 epsilon = %.4e\n', epsilon);
    fprintf('攻击时间窗总数: %d 段\n', length(attack_start));
    for k = 1:length(attack_start)
        fprintf('  第%d段: %.2f s ~ %.2f s\n', k, attack_start(k), attack_end(k));
    end
    fprintf('总采样点数: %d,  其中攻击段点数: %d,  正常段点数: %d\n', ...
            num_points, TP+FN, FP+TN);
    fprintf('--------------------------------------\n');
    fprintf('  TP = %d,  FN = %d,  FP = %d,  TN = %d\n', TP, FN, FP, TN);
    fprintf('--------------------------------------\n');
    fprintf('  检测率   (Detection Rate)     = %.4f\n', DetRate);
    fprintf('  误报率   (False Alarm Rate)  = %.4f\n', FalseAlarmRate);
    fprintf('  漏报率   (Miss Rate)         = %.4f\n', MissRate);
    fprintf('======================================\n\n');
end