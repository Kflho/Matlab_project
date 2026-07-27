% axes_setting_3d.m
% 三维坐标轴样式设置

set(gca, 'Box',          'on');
set(gca, 'BoxStyle',     'back');
set(gca, 'LineWidth',    1.0);

set(gca, 'XTickLabelRotation', 0);
set(gca, 'YTickLabelRotation', 0);
set(gca, 'ZTickLabelRotation', 0);

set(gca, 'FontName',     'Arial');
set(gca, 'FontSize',     9);
set(gca, 'FontWeight',   'normal');

set(gca, 'View',         [65, 30]);    % 默认视角
set(gca, 'DataAspectRatio', [1 1 1]);  % 等比例（可按需调整）