function K=calculate_lqr(A,B)
%指定QR矩阵，计算控制率
Q = [0.65 0 0 0;
    0 0.62 0 0
    0 0 0 0;
    0 0 0 0
    ];
R = [0.813 0;
    0 0.804
    ];
K = dlqr(A,B,Q,R);   %输出LQR控制器的K矩阵

