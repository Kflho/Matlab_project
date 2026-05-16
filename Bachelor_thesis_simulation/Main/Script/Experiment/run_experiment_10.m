function [kappa_opt, epsilon_opt] = run_experiment_10(exp, watermarks, do_plot)
    if nargin < 3, do_plot = true; end
% run_experiment_10  实验10：基于仿真数据的贪心最优 κ 搜索
% 输入 exp 需包含：watermark_idx, start_time_QW, start_time_FDIA,
% FDIA_length, d_target, ramp_len, sign_vec, attack_start, attack_end,
% scheme_name, cf, cm, lambda
% 返回：kappa_opt, epsilon_opt

    Ts = 1;  rng(2026);

    % ---- 创建受控系统 ----
    [G, H, C, D, x_eq, u_eq, y_eq] = Create_shoukong;
    H_ext = [H, eye(4)];
    Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
    Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];
    K = Calculate_LQR(G, H);
    K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -0.1607];
    Gw = G - K_KF*C - H*K;   Hw = K_KF;

    % 水印库
    % watermarks(1).name = '粗选弱'; watermarks(1).Cw = [1 1 1 1; 1 1 1 1]; watermarks(1).Dw = [0.9 0; 0 0.9];
    % watermarks(2).name = '粗选强'; watermarks(2).Cw = [0.5 0.5 0.5 0.5; 0.5 0.5 0.5 0.5]; watermarks(2).Dw = [0.5 0; 0 0.5];
    % watermarks(3).name = '最优弱'; watermarks(3).Cw = [0 -0.3 -1 -1; -0.8 0.3 -1 -0.5]; watermarks(3).Dw = [0.9 0; 0 0.9];
    % watermarks(4).name = '最优强'; watermarks(4).Cw = [0.2 -0.4 0.3 -1; -0.3 0.1 -0.9 0.1]; watermarks(4).Dw = [0.35 0; 0 0.3];

    % 仿真时长
    analog_time = exp.start_time_FDIA + exp.FDIA_length;

    % ---- 水印处理 ----
    wm_idx = exp.watermark_idx;
    wm_start = exp.start_time_QW;
    if wm_idx > 0
        Cw = watermarks(wm_idx).Cw;
        Dw = watermarks(wm_idx).Dw;
        [Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);
    else
        Cw = zeros(2,4); Dw = eye(2);
        Gq = zeros(size(Gw)); Hq = zeros(size(Hw));
        Cq = zeros(2,4); Dq = eye(2);
        if wm_start <= analog_time, wm_start = analog_time + 1; end
    end

    % ---- 攻击序列 ----
    simin_FDIA = Create_FDIA_MinEnergy_LP_fixedsign_par(G, C, K_KF, ...
        exp.FDIA_length, exp.d_target, exp.sign_vec, exp.start_time_FDIA, Ts, exp.ramp_len);

    % ---- 噪声 ----
    [simin_noise_Wk, simin_noise_Vk, simin_noise_Va, Vk,Va, Wk] = Create_noise_v2(analog_time);
    I_a = eye(length(G));

    % ---- 清理并推送变量 ----
    dynamic_vars = {'Ts','analog_time','start_time_FDIA','FDIA_length','start_time_QW', ...
                    'G','H','C','D','Cj','Dj','K','K_KF','Gw','Hw','H_ext',...
                    'Cw','Dw','Gq','Hq','Cq','Dq',...
                    'simin_FDIA','simin_noise_Vk','simin_noise_Va','simin_noise_Wk','Vk','Wk','I_a','Va',...
                    'x_eq','u_eq','y_eq'};
    for k = 1:length(dynamic_vars)
        if evalin('base', ['exist(''', dynamic_vars{k}, ''',''var'')']), evalin('base', ['clear ', dynamic_vars{k}]); end
    end
    assignin('base','Ts',Ts); assignin('base','analog_time',analog_time);
    assignin('base','start_time_FDIA',exp.start_time_FDIA); assignin('base','FDIA_length',exp.FDIA_length);
    assignin('base','start_time_QW',wm_start);
    assignin('base','G',G); assignin('base','H',H); assignin('base','H_ext',H_ext);
    assignin('base','C',C); assignin('base','D',D);
    assignin('base','Cj',Cj); assignin('base','Dj',Dj);
    assignin('base','K',K); assignin('base','K_KF',K_KF);
    assignin('base','Gw',Gw); assignin('base','Hw',Hw);
    assignin('base','Cw',Cw); assignin('base','Dw',Dw);
    assignin('base','Gq',Gq); assignin('base','Hq',Hq);
    assignin('base','Cq',Cq); assignin('base','Dq',Dq);
    assignin('base','simin_FDIA',simin_FDIA);
    assignin('base','simin_noise_Va',simin_noise_Va); assignin('base','simin_noise_Wk',simin_noise_Wk);
    assignin('base','simin_noise_Vk',simin_noise_Vk);
    assignin('base','Vk',Vk); assignin('base','Wk',Wk);
    assignin('base','I_a',I_a); assignin('base','Va',Va);
    assignin('base','x_eq',x_eq); assignin('base','u_eq',u_eq); assignin('base','y_eq',y_eq);

    % ---- 仿真 ----
    out = sim('Control_system_v6');

    % ---- 提取残差能量序列 ----
    r_data = out.r.Data;
    if size(r_data,1)==length(out.r.Time)
        norm_r = sum(r_data.^2,2);
    else
        norm_r = sum(r_data.^2,1)';
    end
    r2_ts = timeseries(norm_r, out.r.Time);

    % ---- 计算理论 μ0, σ² ----
    if wm_idx == 0
        noise_cov = Vk;               % 无水印用观测噪声
    else
        noise_cov = Va;               % 有水印用通信噪声
    end
    Sigma = Dq * noise_cov * Dq';
    mu0_theo = trace(Sigma);
    sigma2_theo = 2 * trace(Sigma^2);

    % ---- 搜索最优 κ ----
    cf = exp.cf;  cm = exp.cm;  lambda = exp.lambda;
    kappa_range = 0:0.01:40;   % 可根据需要调整
    [k_opt, e_opt, k_range, Pf, Pd, Pm] = SearchKappaFromResidual_Theory(r2_ts, ...
        exp.attack_start, exp.attack_end, mu0_theo, sigma2_theo, cf, cm, lambda, kappa_range);

    kappa_opt = k_opt;
    epsilon_opt = e_opt;

    % ---- 输出单个方案结果 ----
    scheme_name = exp.scheme_name;
    fprintf('方案：%s, 最优 κ = %.2f, 最优阈值 ε* = %.6f\n', scheme_name, k_opt, e_opt);
    fprintf('  μ0 = %.6f, σ² = %.6e\n', mu0_theo, sigma2_theo);



if do_plot
    % ---- 绘制并保存曲线（可选） ----
    out_dir = fullfile('Figures', '10_Optimal_Kappa');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    figure('Color','w','Position',[100,100,800,500]);
    hold on;
    plot(k_range, Pd, 'b-','LineWidth',1.5,'DisplayName','检测率 P_d');
    plot(k_range, Pf, 'r--','LineWidth',1.5,'DisplayName','误报率 P_f');
    plot(k_range, Pm, 'm-.','LineWidth',1.5,'DisplayName','漏报率 P_m');
    xline(k_opt, 'k-','LineWidth',1.2,'DisplayName',sprintf('最优 \\kappa = %.2f', k_opt));
    xlabel('\kappa'); ylabel('概率');
    title(sprintf('%s 检测性能随 \\kappa 的变化', scheme_name));
    legend('Location','best'); grid on;
    hold off;

    if exist('fig_setting','file')==2
        fig_setting; axes_setting_2d; label_setting_2d; legend_setting; title_setting;
    else
        set(gca,'FontName','宋体','FontSize',9);
    end

    if exist('Export_fig_paper','file')==2
        Export_fig_paper(gcf, fullfile(out_dir, sprintf('performance_curve_%s', scheme_name)), 5.5);
    else
        saveas(gcf, fullfile(out_dir, sprintf('performance_curve_%s.png', scheme_name)));
    end

    % ---- 将最优指标保存到文件 ----
    % 找到最优 kappa 对应的索引
    [~, idx_opt] = min(abs(k_range - k_opt));
    Pd_opt = Pd(idx_opt);
    Pf_opt = Pf(idx_opt);
    Pm_opt = Pm(idx_opt);

    % 输出目录已存在 (out_dir)
    result_file = fullfile(out_dir, 'optimal_metrics.csv');
    % 如果文件不存在，写入表头
    if ~exist(result_file, 'file')
        fid = fopen(result_file, 'w');
        fprintf(fid, '方案名称,最优κ,最优阈值,检测率Pd,误报率Pf,漏报率Pm\n');
        fclose(fid);
    end
    % 追加当前方案数据
    fid = fopen(result_file, 'a');
    fprintf(fid, '%s,%.2f,%.6f,%.4f,%.4f,%.4f\n', ...
            scheme_name, k_opt, e_opt, Pd_opt, Pf_opt, Pm_opt);
    fclose(fid);
    fprintf('  已将最优指标追加至：%s\n', result_file);

    
    close(gcf);
end
end