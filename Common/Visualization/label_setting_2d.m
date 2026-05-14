% label_setting_2d.m
% 设置 X、Y 轴标签文字与字号
% 使用前需先调用 xlabel / ylabel 设置字符串

% ---- 字体 ----
% set(gca, 'FontName',     'Arial');     % 无中文用 Arial
set(gca, 'FontName',   '宋体');  % 有中文用微软雅黑

hXLabel = get(gca, 'XLabel');
hYLabel = get(gca, 'YLabel');

set(hXLabel, 'FontName', '宋体', 'FontSize', 10, 'FontWeight', 'normal');
set(hYLabel, 'FontName', '宋体', 'FontSize', 10, 'FontWeight', 'normal');