% tire_stud_detector.m
clear; clc; close all;

imageFiles = {'studded_tire.jpeg', 'summer_tire.jpg'};

for i = 1:numel(imageFiles)

    % ---------- 1) Read & resize ----------
    I = imread(imageFiles{i});
    I = imresize(I, 0.5);   % optional scaling

    % ---------- 2) Convert to grayscale ----------
    if size(I,3) == 3
        Igray = rgb2gray(I);
    else
        Igray = I;
    end
    Igray = im2double(Igray);   % work in [0,1]

    % ---------- 3) Create tire mask ----------
    % Tire is darker than background, so threshold for dark region
    level = graythresh(Igray);          % Otsu threshold
    tireMask = Igray < level;           % dark = tire

    % Clean tire mask: fill holes & remove small objects
    tireMask = imfill(tireMask, 'holes');
    tireMask = bwareaopen(tireMask, 2000);  % remove very small blobs

    % Optional: smooth mask slightly
    seTire = strel('disk', 5);
    tireMask = imopen(tireMask, seTire);

    % ---------- 4) Candidate studs ----------
    % Studs are bright points inside the tire
    brightThresh = 0.75;   % works in [0,1], tweak if needed
    cand = (Igray > brightThresh) & tireMask;

    % Clean candidate mask: remove tiny specks, smooth
    cand = bwareaopen(cand, 3);         % remove very small noise
    seStud = strel('disk', 1);
    cand = imopen(cand, seStud);        % small opening
    cand = imclose(cand, seStud);       % close tiny gaps

    % ---------- 5) Connected components ----------
    CC = bwconncomp(cand);
    stats = regionprops(CC, 'Area', 'Perimeter', 'Eccentricity', 'PixelIdxList');

    % ---------- 6) Filter candidates ----------
    studMask = false(size(cand));
    studCount = 0;

    % Reasonable limits (may tune for your images)
    minA   = 4;      % min area of a stud
    maxA   = 120;    % max area of a stud
    minCirc = 0.6;   % minimum circularity
    maxEcc  = 0.85;  % maximum eccentricity

    for k = 1:numel(stats)
        A  = stats(k).Area;
        P  = stats(k).Perimeter;
        E  = stats(k).Eccentricity;

        if P == 0
            continue;
        end

        % Circularity: 1 = perfect circle, <1 = less circular
        circ = 4 * pi * A / (P^2);

        if (A >= minA) && (A <= maxA) && ...
           (circ >= minCirc) && (E <= maxEcc)
            studMask(CC.PixelIdxList{k}) = true;
            studCount = studCount + 1;
        end
    end

    % ---------- 7) Decision rule ----------
    tireArea = nnz(tireMask);
    density  = studCount / max(tireArea,1);   % avoid division by zero

    % Simple rule: many studs → studded
    % You can tweak thresholds depending on your images.
    isStudded = (studCount > 10) || (density > 5e-4);

    % ---------- 8) Visualization ----------
    figure;
    subplot(1,3,1);
    imshow(I);
    title(sprintf('Input: %s', imageFiles{i}), 'Interpreter','none');

    subplot(1,3,2);
    imshow(cand);
    title('Candidate studs (binary)');

    subplot(1,3,3);
    imshow(I); hold on;
    visboundaries(studMask, 'LineWidth', 0.7);

    if isStudded
        title(sprintf('STUDDED TIRE (studs: %d)', studCount));
    else
        title(sprintf('NON-STUDDED TIRE (studs: %d)', studCount));
    end

end
