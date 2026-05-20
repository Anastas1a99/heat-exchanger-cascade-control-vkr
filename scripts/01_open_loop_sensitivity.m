% Оценка чувствительности разомкнутой модели теплообменника

clc; clear; close all;

%% 1. Исходные параметры

mdl = 'vkrzam';          % разомкнутая модель объекта
load_system(mdl);

t0 = 300;                % момент подачи ступеньки, с
sim_end = 800;           % длительность моделирования, с

names = {'Расход пара G_п (+10%, +0.067 кг/с)', ...
         'Расход продукта G_1 (+10%, +1.2 кг/с)', ...
         'Температура продукта на входе T_{in} (+10%, +3°C)', ...
         'Температура пара T_п (+3%, +4°C)'};

param_short = {'Расход пара G_п (+10%)', ...
               'Расход продукта G_1 (+10%)', ...
               'Темп. на входе T_in (+10%)', ...
               'Темп. пара T_п (+3%)'};

%% 2. Конфигурации расчётных экспериментов

exp_configs = {
    {{'vkrzam/G_пара_ном',  '0.67', '0.737'}, ...
     {'vkrzam/ΔG_продукта', '0',    '0'}, ...
     {'vkrzam/ΔT_вх',       '0',    '0'}, ...
     {'vkrzam/ΔT_пара',     '0',    '0'}};

    {{'vkrzam/G_пара_ном',  '0.67', '0.67'}, ...
     {'vkrzam/ΔG_продукта', '0',    '1.2'}, ...
     {'vkrzam/ΔT_вх',       '0',    '0'}, ...
     {'vkrzam/ΔT_пара',     '0',    '0'}};

    {{'vkrzam/G_пара_ном',  '0.67', '0.67'}, ...
     {'vkrzam/ΔG_продукта', '0',    '0'}, ...
     {'vkrzam/ΔT_вх',       '0',    '3.0'}, ...
     {'vkrzam/ΔT_пара',     '0',    '0'}};

    {{'vkrzam/G_пара_ном',  '0.67', '0.67'}, ...
     {'vkrzam/ΔG_продукта', '0',    '0'}, ...
     {'vkrzam/ΔT_вх',       '0',    '0'}, ...
     {'vkrzam/ΔT_пара',     '0',    '4.0'}};
};

%% 3. Запуск моделирования

all_t = cell(1, 4);
all_T = cell(1, 4);

for k = 1:4
    fprintf('Запуск эксперимента %d: %s\n', k, param_short{k});

    cfg = exp_configs{k};

    for j = 1:4
        blk = cfg{j}{1};
        before_val = cfg{j}{2};
        after_val = cfg{j}{3};

        set_param(blk, 'Before', before_val, 'After', after_val);
    end

    simOut = sim(mdl, 'StopTime', num2str(sim_end));

    switch k
        case 1
            ts = simOut.out_Gp;
        case 2
            ts = simOut.out_G1;
        case 3
            ts = simOut.out_Tin;
        case 4
            ts = simOut.out_Tp;
    end

    all_t{k} = ts.Time(:);
    all_T{k} = ts.Data(:);

    fprintf('  Записано точек: %d\n', length(all_t{k}));
end

%% 4. Расчёт показателей чувствительности

dT_ss_arr = zeros(1, 4);
t_settle_arr = zeros(1, 4);
sign_str = cell(1, 4);
T_pre_arr = zeros(1, 4);

fprintf('\n============================================================\n');
fprintf('РЕЗУЛЬТАТЫ АНАЛИЗА ЧУВСТВИТЕЛЬНОСТИ ОБЪЕКТА УПРАВЛЕНИЯ\n');
fprintf('============================================================\n\n');

for k = 1:4
    t = all_t{k};
    T = all_T{k};

    pre_idx = t >= (t0 - 30) & t < t0;
    T_pre = mean(T(pre_idx));
    T_pre_arr(k) = T_pre;

    ss_idx = t >= (sim_end - 300);
    dT_ss = mean(T(ss_idx)) - T_pre;
    dT_ss_arr(k) = dT_ss;

    band = 0.05 * abs(dT_ss);

    post_idx = t >= t0;
    t_post = t(post_idx);
    T_post = T(post_idx);

    outside = abs(T_post - (T_pre + dT_ss)) > band;
    last_out = find(outside, 1, 'last');

    if isempty(last_out)
        t_settle = 0;
    else
        t_settle = t_post(last_out) - t0;
    end

    t_settle_arr(k) = t_settle;

    if dT_ss >= 0
        sign_str{k} = 'Возрастание';
    else
        sign_str{k} = 'Убывание';
    end

    fprintf('Эксперимент %d: %s\n', k, names{k});
    fprintf('  Температура до ступеньки:        %.4f °C\n', T_pre);
    fprintf('  Установившееся отклонение:       %+.4f °C\n', dT_ss);
    fprintf('  Время установления, 5%%:          %.0f с\n', t_settle);
    fprintf('  Характер изменения:              %s\n\n', sign_str{k});
end

%% 5. Сводная таблица

fprintf('============================================================\n');
fprintf('СВОДНАЯ ТАБЛИЦА\n');
fprintf('============================================================\n');
fprintf('%-42s | %10s | %8s | %s\n', ...
    'Входной параметр', 'dT_уст, °C', 't_уст, с', 'Характер');
fprintf('%s\n', repmat('-', 1, 82));

for k = 1:4
    fprintf('%-42s | %+10.2f | %8.0f | %s\n', ...
        param_short{k}, dT_ss_arr(k), t_settle_arr(k), sign_str{k});
end

fprintf('\n');

[~, i_main] = max(abs(dT_ss_arr));

fprintf('Наибольшее отклонение: эксперимент %d — %s\n', ...
    i_main, param_short{i_main});
fprintf('Данный параметр оказывает наибольшее влияние на выходную температуру.\n\n');

%% 6. Построение графика

figure('Color', 'w', 'Position', [100 100 1400 850]);
hold on;

colors = {'b', 'r', [0.47 0.67 0.19], [0.75 0.0 0.75]};

dT_final = zeros(1, 4);
dT_all = cell(1, 4);

for k = 1:4
    dT = all_T{k} - T_pre_arr(k);
    dT_all{k} = dT;

    idx_last = find(isfinite(dT), 1, 'last');
    dT_final(k) = dT(idx_last);

    plot(all_t{k}, dT, ...
        'Color', colors{k}, ...
        'LineWidth', 2.2, ...
        'DisplayName', names{k});
end

yline(0, '--k', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'Нулевое отклонение');

xline(t0, ':k', ...
    'LineWidth', 1.2, ...
    'HandleVisibility', 'off');

text(t0 + 10, 0.15, 'Момент ступеньки', ...
    'FontSize', 12, ...
    'Color', [0.4 0.4 0.4], ...
    'Rotation', 90, ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom');

grid on;
box on;

xlabel('Время, с', 'FontSize', 15);
ylabel('Отклонение температуры \DeltaT_{вых}, °C', 'FontSize', 15);
title('Реакция объекта управления на ступенчатые воздействия', ...
    'FontSize', 16, ...
    'FontWeight', 'bold');

xlim([250 sim_end]);
set(gca, 'FontSize', 13, 'LineWidth', 1.0);

ax = gca;

all_dT_values = cell2mat(dT_all);
y_min = min([all_dT_values(:); 0; dT_final(:)]);
y_max = max([all_dT_values(:); 0; dT_final(:)]);
y_range = y_max - y_min;

if y_range == 0
    y_range = 1;
end

ylim([y_min - 0.25*y_range, y_max + 0.08*y_range]);

base_ticks = yticks;
special_ticks = round([0, dT_final], 3);
new_ticks = sort(unique(round([base_ticks, special_ticks], 3)));

yticks(new_ticks);
yticklabels(compose('%.3g', new_ticks));

lgd = legend('FontSize', 12);
lgd.Units = 'normalized';

drawnow;

ax.Units = 'normalized';
ax_pos = ax.Position;
lgd_pos = lgd.Position;

yl = ylim(ax);
y0_norm = (0 - yl(1)) / (yl(2) - yl(1));

legend_x = ax_pos(1) + ax_pos(3) - lgd_pos(3) - 0.01;
legend_y = ax_pos(2) + ax_pos(4)*y0_norm - lgd_pos(4) - 0.02;
legend_y = max(ax_pos(2) + 0.01, legend_y);

lgd.Position(1) = legend_x;
lgd.Position(2) = legend_y;

exportgraphics(gcf, 'sensitivity_analysis.png', 'Resolution', 300);

fprintf('График сохранён: sensitivity_analysis.png\n');
