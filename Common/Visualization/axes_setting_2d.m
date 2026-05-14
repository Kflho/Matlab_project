% axes_setting_2d.m
% 二维坐标轴样式设置

% ---- 刻度方向与边框 ----
set(gca, 'Box',          'on');        % 四面边框
set(gca, 'TickDir',      'in');        % 刻度线朝内
set(gca, 'TickLength',   [0.015 0.015]); % 刻度线长度

% ---- 坐标轴线宽 ----
set(gca, 'LineWidth',    1.0);

% ---- 刻度标签旋转 ----
set(gca, 'XTickLabelRotation', 0);
set(gca, 'YTickLabelRotation', 0);

% ---- 字体 ----
% set(gca, 'FontName',     'Arial');     % 无中文用 Arial
set(gca, 'FontName',   '宋体');  % 有中文用微软雅黑
set(gca, 'FontSize',     9);           % IEEE 推荐 8-10pt
set(gca, 'FontWeight',   'normal');

% ---- 网格（论文中根据需要开启）----
% set(gca, 'XGrid', 'on', 'YGrid', 'on');
% set(gca, 'GridLineStyle', '--');
% set(gca, 'GridAlpha', 0.3);