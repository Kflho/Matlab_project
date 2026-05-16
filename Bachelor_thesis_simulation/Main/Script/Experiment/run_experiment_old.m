function run_experiment(exp)
% run_experiment  独立执行单次实验（仿真、画图、导出）
%   所有系统矩阵在函数内部创建并推送到基础工作区。
%   绘图标题使用原始名称，不加前缀。

    Ts = 1;
    rng(2026);

    % ---- 1. 创建受控系统 ----
    [G, H, C, D, x_eq, u_eq, y_eq] = Create_shoukong;
    H_ext = [H, eye(4)];
    Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
    Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];
    K = Calculate_LQR(G, H);
    K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -0.1607];
    Gw = G - K_KF*C - H*K;
    Hw = K_KF;


    % 水印库
    watermarks(1).name = '粗选弱'; watermarks(1).Cw = [1 1 1 1; 1 1 1 1]; watermarks(1).Dw = [0.9 0; 0 0.9];
    watermarks(2).name = '粗选强'; watermarks(2).Cw = [0.5 0.5 0.5 0.5; 0.5 0.5 0.5 0.5]; watermarks(2).Dw = [0.5 0; 0 0.5];
    watermarks(3).name = '最优弱'; watermarks(3).Cw = [0 -0.3 -1 -1; -0.8 0.3 -1 -0.5]; watermarks(3).Dw = [0.9 0; 0 0.9];
    watermarks(4).name = '最优强'; watermarks(4).Cw = [0.2 -0.4 0.3 -1; -0.3 0.1 -0.9 0.1]; watermarks(4).Dw = [0.35 0; 0 0.3];

    % ---- 仿真停止时间 ----
    if isfield(exp, 'calc_stats') && exp.calc_stats
        analog_time = exp.stat_sim_duration;
    else
        analog_time = exp.start_time_FDIA + exp.FDIA_length;
    end

    % ---- 2. 水印处理 ----
    if isfield(exp, 'watermark_idx') && exp.watermark_idx > 0
        Cw = watermarks(exp.watermark_idx).Cw;
        Dw = watermarks(exp.watermark_idx).Dw;
        [Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);
        fprintf('  使用水印：%s\n', watermarks(exp.watermark_idx).name);
    else
        % 无水印：提供与有水印时相同维度的零矩阵
         % 无水印：设置“透明水印”——Dw=I, Dq=I，其余为零
        Cw = zeros(2, 4);
        Dw = eye(2);          % 嵌入器直通：yw = y
        Gq = zeros(size(Gw)); % 移除器状态矩阵置零
        Hq = zeros(size(Hw)); % 移除器状态矩阵置零
        Cq = zeros(2, 4);
        Dq = eye(2);          % 移除器直通：yqw = yw = y
        if exp.start_time_QW <= analog_time
            exp.start_time_QW = analog_time + 1;
        end
        fprintf('  未使用水印 (start_time_QW=%d, analog_time=%d)\n', exp.start_time_QW, analog_time);
    end

    % ---- 攻击序列 ----
    simin_FDIA = Create_FDIA_MinEnergy_LP_fixedsign_par(G, C, K_KF, ...
        exp.FDIA_length, exp.d_target, exp.sign_vec, exp.start_time_FDIA, Ts, exp.ramp_len);

    % ---- 噪声 ----
    [simin_noise_Wk, simin_noise_Vk, simin_noise_Va, Vk, Wk] = Create_noise_v2(analog_time);
    I_a = eye(length(G));
    Va = diag([0.003844, 0.004032]);

    % ---- 3. 清理基础工作区中可能干扰 Simulink 的旧变量（只删除会推送的变量） ----
    dynamic_vars = {'Ts','analog_time','start_time_FDIA','FDIA_length','start_time_QW', ...
                    'G','H','C','D','Cj','Dj','K','K_KF','Gw','Hw','H_ext' ...
                    'Cw','Dw','Gq','Hq','Cq','Dq', ...
                    'simin_FDIA','simin_noise_Vk','simin_noise_Va','simin_noise_Wk','Vk','Wk','I_a','Va', ...
                    'x_eq','u_eq','y_eq'};
    for k = 1:length(dynamic_vars)
        if evalin('base', ['exist(''', dynamic_vars{k}, ''',''var'')'])
            evalin('base', ['clear ', dynamic_vars{k}]);
        end
    end

    % ---- 4. 推送所有需要的变量到基础工作区 ----
    assignin('base', 'Ts',                Ts);
    assignin('base', 'analog_time',       analog_time);
    assignin('base', 'start_time_FDIA',   exp.start_time_FDIA);
    assignin('base', 'FDIA_length',       exp.FDIA_length);
    assignin('base', 'start_time_QW',     exp.start_time_QW);
    assignin('base', 'G',   G); assignin('base', 'H',   H);assignin('base', 'H_ext',   H_ext);
    assignin('base', 'C',   C); assignin('base', 'D',   D);
    assignin('base', 'Cj', Cj); assignin('base', 'Dj', Dj);
    assignin('base', 'K',   K); assignin('base', 'K_KF', K_KF);
    assignin('base', 'Gw', Gw); assignin('base', 'Hw', Hw);
    assignin('base', 'Cw', Cw); assignin('base', 'Dw', Dw);
    assignin('base', 'Gq', Gq); assignin('base', 'Hq', Hq);
    assignin('base', 'Cq', Cq); assignin('base', 'Dq', Dq);
    assignin('base', 'simin_FDIA',        simin_FDIA);
    assignin('base', 'simin_noise_Va',    simin_noise_Va);
    assignin('base', 'simin_noise_Wk',    simin_noise_Wk);
    assignin('base', 'simin_noise_Vk',    simin_noise_Vk);
    assignin('base', 'Vk', Vk); assignin('base', 'Wk', Wk);
    assignin('base', 'I_a', I_a);
    assignin('base', 'Va', Va);
    assignin('base', 'x_eq', x_eq); assignin('base', 'u_eq', u_eq); assignin('base', 'y_eq', y_eq);

    % ---- 5. 运行仿真 ----
    fprintf('  仿真运行中... (analog_time = %d)\n', analog_time);

    
    % 然后再运行仿真
    out = sim('Control_system_v6');
    % ---- 6. 计算信号 ----
    r2   = Calculate_energy(out.r);
    yj2  = Calculate_energy(out.y_j);
    FDIA2 = Calculate_energy(simin_FDIA);
% ---- 7. 统计实验专用输出 ----
% ---- 特殊实验处理 ---

% --- 特殊实验：为贪心阈值搜索准备残差数据 ---
if isfield(exp, 'calc_optimal_kappa') && exp.calc_optimal_kappa
    % 生成残差模平方时间序列
    r_data = out.r.Data;
    if size(r_data, 1) == length(out.r.Time)
        norm_r = sum(r_data.^2, 2);
    else
        norm_r = sum(r_data.^2, 1)';
    end
    r2_ts = timeseries(norm_r, out.r.Time);
    assignin('base', 'r2_ts', r2_ts);   % 存入基础工作区，供 batch 脚本取用
    fprintf('  残差能量序列已保存到基础工作区变量 r2_ts。\n');
    return;
end




    if isfield(exp, 'calc_stats') && exp.calc_stats
        fprintf('--- 长期性能损失统计 [%s] ---\n', exp.name);
        Calculate_Signal_Stats(out.y_j, 0, analog_time);
        return;
    end

    % ---- 8. 绘图并保存（不添加实验前缀） ----
    export_dir = fullfile(exp.export_root, exp.name);
    if ~exist(export_dir, 'dir'), mkdir(export_dir); end
    fprintf('  图片将保存到：%s\n', export_dir);

    if exp.plot_residual
        figure('Name', '攻击前后残差对比图');
        Plot_signals_v5(out.r, 'r', '攻击前后残差对比图', 1, {'t/s', 'r/cm'});
        Add_Threshold(exp.threshold_value, exp.threshold_label);
        Export_fig_paper(gcf, fullfile(export_dir, 'fig_residual'), 5.5);
    end
    if exp.plot_liquid_level
        figs_before = findobj('Type', 'figure');
        Plot_signals_v5(out.x, 'x', '攻击前后液位对比图', 3, {'t/s', 'x/cm'});
        figs_after  = findobj('Type', 'figure');
        hFigs_liquid = setdiff(figs_after, figs_before, 'stable');
        for k = 1:length(hFigs_liquid)
            Export_fig_paper(hFigs_liquid(k), fullfile(export_dir, sprintf('fig_liquid_level_%d', k)), 5.5);
        end
    end
    if exp.plot_residual_square
        figure('Name', '攻击前后残差模长平方对比图');
        Plot_signals_v5(r2, 'r^2', '攻击前后残差模长平方对比图', 1, {'t/s', '|r|^2/cm^2'}, {'|r|^2'});
        Add_Threshold(exp.threshold_square_val, exp.threshold_square_lbl);
        Export_fig_paper(gcf, fullfile(export_dir, 'fig_residual_square'), 5.5);
    end
    if exp.plot_performance
        figure('Name', '攻击前后性能影响参数对比图');
        Plot_signals_v5(yj2, 'yj^2', '攻击前后性能影响参数对比图', 1, {'时间/t', '|y_j|^2'}, {'|y_j|^2'});
        Export_fig_paper(gcf, fullfile(export_dir, 'fig_performance'), 5.5);
    end
    if exp.plot_attack_energy
        figure('Name', '攻击能量图');
        Plot_signals_v5(FDIA2, 'a(t)^2', '攻击能量图', 1, {'t/s', '|a|^2/cm^2'}, {'|a|^2'});
        Export_fig_paper(gcf, fullfile(export_dir, 'fig_attack_energy'), 5.5);
    end

    fprintf('  实验 [%s] 完成。\n', exp.name);
end