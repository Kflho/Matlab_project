% title_setting.m
% 设置标题样式
% 调用方式：先 title('xxx')，再 title_setting;

hTitle = get(gca, 'Title');

set(hTitle, 'FontName',  '宋体');        % 这里原来是 Arial，导致中文变方块
set(hTitle, 'FontSize',  10);
set(hTitle, 'FontWeight', 'bold');