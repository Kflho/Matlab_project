function run_experiment_9(exp, watermarks)
% run_experiment_9  实验9：阈值对比及残差能量图绘制（自包含版本）
% 内部自动调用实验10获取最优κ和阈值，无需外部传入。
% 参数：
%   exp        - 实验配置结构体，需包含攻击、水印、绘图等字段
%   watermarks - 水印库结构体（由batch脚本统一传入）

    % ---- 默认导出根目录 ----
    if ~isfield(exp, 'export_root')
        exp.export_root = 'Figures';
    end

    Ts = 1;
    rng(2026);

    % ---- 创建受控系统 ----
    [G, H, C, D, x_eq, u_eq, y_eq] = Create_shoukong;
    H_ext = [H, eye(4)];
    Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
    Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];
    K = Calculate_LQR(G, H);
    K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -0.1607];
    Gw = G - K_KF*C - H*K;
    Hw = K_KF;

    % ---- 原有阈值（若未指定则取0.1） ----
    if isfield(exp, 'original_epsilon')
        orig_epsilon = exp.original_epsilon;
    else
        orig_epsilon = 0.1;
    end

    % ---- 内部调用实验10，获取该水印方案的最优阈值 ----
    fprintf('  正在运行实验10以获取最优κ和阈值...\n');
    if exp.watermark_idx > 0
        exp10.scheme_name = watermarks(exp.watermark_idx).name;
    else
        exp10.scheme_name = '无水印';
    end
    exp10.watermark_idx = exp.watermark_idx;
    % ... 其余不变 ...

    exp10.start_time_QW = exp.start_time_QW;
    exp10.start_time_FDIA = exp.start_time_FDIA;
    exp10.FDIA_length = exp.FDIA_length;
    exp10.d_target = exp.d_target;
    exp10.ramp_len = exp.ramp_len;
    exp10.sign_vec = exp.sign_vec;
    exp10.attack_start = exp.attack_start;
    exp10.attack_end = exp.attack_end;
    exp10.cf = 1;          % 与独立实验10保持一致
    exp10.cm = 1;
    exp10.lambda = 0;



    [~, epsilon_opt] = run_experiment_10(exp10, watermarks, false);  % 不绘图
    fprintf('  实验10返回的最优阈值 ε* = %.6f\n', epsilon_opt);

    % ---- 仿真停止时间 ----
    analog_time = exp.start_time_FDIA + exp.FDIA_length;

    % ---- 水印处理 ----
    if exp.watermark_idx > 0
        Cw = watermarks(exp.watermark_idx).Cw;
        Dw = watermarks(exp.watermark_idx).Dw;
        [Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);
        fprintf('  使用水印：%s\n', watermarks(exp.watermark_idx).name);
    else
        % 无水印：透明水印
        Cw = zeros(2,4);
        Dw = eye(2);
        Gq = zeros(size(Gw));
        Hq = zeros(size(Hw));
        Cq = zeros(2,4);
        Dq = eye(2);
        if exp.start_time_QW <= analog_time
            exp.start_time_QW = analog_time + 1;
        end
        fprintf('  未使用水印 (start_time_QW=%d, analog_time=%d)\n', exp.start_time_QW, analog_time);
    end

    % ---- 生成攻击序列 ----
    simin_FDIA = Create_FDIA_MinEnergy_LP_fixedsign_par(G, C, K_KF, ...
        exp.FDIA_length, exp.d_target, exp.sign_vec, exp.start_time_FDIA, Ts, exp.ramp_len);

    % ---- 生成噪声 ----
    [simin_noise_Wk, simin_noise_Vk, simin_noise_Va, Vk,Va, Wk] = Create_noise_v2(analog_time);
    I_a = eye(length(G));

    % ---- 清理并推送变量到基础工作区 ----
    dynamic_vars = {'Ts','analog_time','start_time_FDIA','FDIA_length','start_time_QW', ...
                    'G','H','C','D','Cj','Dj','K','K_KF','Gw','Hw','H_ext',...
                    'Cw','Dw','Gq','Hq','Cq','Dq',...
                    'simin_FDIA','simin_noise_Vk','simin_noise_Va','simin_noise_Wk','Vk','Wk','I_a','Va',...
                    'x_eq','u_eq','y_eq'};
    for k = 1:length(dynamic_vars)
        if evalin('base', ['exist(''', dynamic_vars{k}, ''',''var'')'])
            evalin('base', ['clear ', dynamic_vars{k}]);
        end
    end
    assignin('base', 'Ts',                Ts);
    assignin('base', 'analog_time',       analog_time);
    assignin('base', 'start_time_FDIA',   exp.start_time_FDIA);
    assignin('base', 'FDIA_length',       exp.FDIA_length);
    assignin('base', 'start_time_QW',     exp.start_time_QW);
    assignin('base', 'G',   G); assignin('base', 'H',   H); assignin('base', 'H_ext',   H_ext);
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

    % ---- 运行仿真 ----
    fprintf('  仿真运行中... (analog_time = %d)\n', analog_time);
    out = sim('Control_system_v6');

    % ---- 计算残差模平方时间序列 ----
    r_data = out.r.Data;
    if size(r_data, 1) == length(out.r.Time)
        norm_r = sum(r_data.^2, 2);
    else
        norm_r = sum(r_data.^2, 1)';
    end
    r2_ts = timeseries(norm_r, out.r.Time);
    % 用于绘图的 r2 (timeseries)
    r2 = Calculate_energy(out.r);

    % ---- 新阈值直接采用实验10的结果 ----
    new_epsilon = epsilon_opt;

    % ---- 性能指标 ----
    [Pd_old, Pf_old, Pm_old] = Calculate_DetectionMetrics(r2_ts, orig_epsilon, ...
        exp.attack_start, exp.attack_end);
    [Pd_new, Pf_new, Pm_new] = Calculate_DetectionMetrics(r2_ts, new_epsilon, ...
        exp.attack_start, exp.attack_end);

    if exp.watermark_idx > 0
        wm_name = watermarks(exp.watermark_idx).name;
    else
        wm_name = '无水印';
    end
    fprintf('\n===== 实验 9：阈值对比（水印：%s）=====\n', wm_name);
    fprintf('原有阈值 epsilon_old = %.4f\n', orig_epsilon);
    fprintf('新阈值   epsilon_new = %.4f\n', new_epsilon);
    fprintf('------------ 检测性能对比 ------------\n');
    fprintf('指标         原有阈值      新阈值\n');
    fprintf('检测率    %8.4f      %8.4f\n', Pd_old, Pd_new);
    fprintf('误报率    %8.4f      %8.4f\n', Pf_old, Pf_new);
    fprintf('漏报率    %8.4f      %8.4f\n', Pm_old, Pm_new);
    fprintf('======================================\n');

    % ---- 绘制残差能量图并保存 ----
    export_dir = fullfile(exp.export_root, exp.name);
    if ~exist(export_dir, 'dir')
        mkdir(export_dir);
    end

    figure('Color', 'w');
    plot(r2_ts.Time, r2_ts.Data, 'b-', 'LineWidth', 1.5, 'DisplayName', '|r|^2');
    hold on;
    yline(new_epsilon, '--r', 'LineWidth', 1.5, 'DisplayName', '最优阈值');
    hold off;

    xlabel('t / s');
    ylabel('|r|^2 / cm^2');
    title('攻击前后残差模长平方对比图');
    legend('Location', 'best');
    grid on;
    xlim([r2_ts.Time(1), r2_ts.Time(end)]);

    Run_visualization;   % 应用统一图形格式

    % 导出高分辨率图片
    if exist('Export_fig_paper', 'file') == 2
        Export_fig_paper(gcf, fullfile(export_dir, 'fig_residual_square'), 5.5);
    else
        saveas(gcf, fullfile(export_dir, 'fig_residual_square.png'));
    end
    fprintf('  残差能量图已保存至：%s\n', fullfile(export_dir, 'fig_residual_square.png'));
end