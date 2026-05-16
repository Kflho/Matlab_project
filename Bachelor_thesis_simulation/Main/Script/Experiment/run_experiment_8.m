function run_experiment_8(exp,watermarks)
% 实验8：残差阈值计算（calc_threshold）
    Ts = 1;  rng(2026);
    [G, H, C, D, x_eq, u_eq, y_eq] = Create_shoukong;
    H_ext = [H, eye(4)];
    Cj = [0.806 0 0 0; 0 0.787 0 0; 0 0 5.556 0; 0 0 0 7.143; 0 0 0 0; 0 0 0 0];
    Dj = [0 0; 0 0; 0 0; 0 0; 0.901 0; 0 0.897];
    K = Calculate_LQR(G, H);
    K_KF = [0.4427 0; 0 0.4451; -0.1561 0; 0 -0.1607];
    Gw = G - K_KF*C - H*K;   Hw = K_KF;

    % watermarks(1).name = '粗选弱'; watermarks(1).Cw = [1 1 1 1;1 1 1 1]; watermarks(1).Dw = [0.9 0;0 0.9];
    % watermarks(2).name = '粗选强'; watermarks(2).Cw = [0.5 0.5 0.5 0.5;0.5 0.5 0.5 0.5]; watermarks(2).Dw = [0.5 0;0 0.5];
    % watermarks(3).name = '最优弱'; watermarks(3).Cw = [0 -0.3 -1 -1;-0.8 0.3 -1 -0.5]; watermarks(3).Dw = [0.9 0;0 0.9];
    % watermarks(4).name = '最优强'; watermarks(4).Cw = [0.2 -0.4 0.3 -1;-0.3 0.1 -0.9 0.1]; watermarks(4).Dw = [0.35 0;0 0.3];

    analog_time = exp.stat_sim_duration;

    if exp.watermark_idx > 0
        Cw = watermarks(exp.watermark_idx).Cw;
        Dw = watermarks(exp.watermark_idx).Dw;
        [Gq, Hq, Cq, Dq] = Get_remover_matrices(Gw, Hw, Cw, Dw);
    else
        Cw = zeros(2,4); Dw = eye(2);
        Gq = zeros(size(Gw)); Hq = zeros(size(Hw));
        Cq = zeros(2,4); Dq = eye(2);
        if exp.start_time_QW <= analog_time, exp.start_time_QW = analog_time + 1; end
    end

    simin_FDIA = Create_FDIA_MinEnergy_LP_fixedsign_par(G, C, K_KF, ...
        exp.FDIA_length, exp.d_target, exp.sign_vec, exp.start_time_FDIA, Ts, exp.ramp_len);
    [simin_noise_Wk, simin_noise_Vk, simin_noise_Va, Vk,Va, Wk] = Create_noise_v2(analog_time);
    I_a = eye(length(G));


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
    assignin('base','start_time_QW',exp.start_time_QW);
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

    out = sim('Control_system_v6');  % 虽不攻击，仍需运行仿真

    kappa = 1000;
    if ~isempty(Dq)
        epsilon_r = trace(Dq*Va*Dq') + 2*kappa*trace((Dq*Va*Dq')^2);
        fprintf('  [%s] 残差阈值 epsilon_r = %.4f\n', exp.name, epsilon_r);
    else
        epsilon_r0 = trace(Va) + 2*kappa*trace(Va^2);
        fprintf('  [%s] 无水印残差阈值 epsilon_r0 = %.4f\n', exp.name, epsilon_r0);
    end
end