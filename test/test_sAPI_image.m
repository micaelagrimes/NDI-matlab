function test_sAPI_image(dirname)

%% this function works as a sample test function specifically for the 
%% sAPI_image device (tiffstack)


disp(['Opening a new example sampleAPI with dirname ''exp2''']);
myExp = sampleAPI_dir(dirname);

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize devices ''dev_tiffstack'' ']);

dev1 = sAPI_image_tiffstack('dev_tiffstack',myExp);  

disp('Now will print all the channels :');

disp ( struct2table(getchannels(dev1)) );

disp ( getintervals(dev1) );

% disp(['Examining the amplifier channels versus time:']);

myClock = sampleAPI_clock(dev1,1);

figure;

colormap(gray(256));

result1 = read_channel(dev1,'digitalin',1,myClock,0,50);

result2 = read_channel(dev1,'timestamp',1,myClock,0,Inf);

% result1,
% 
% result2,
% 
% figure;
% plot(result1.data);
% box off;
% ylabel('Digital value');
% xlabel('Sample number');
% 
% channel = 'ai0';
% sr = getsamplerate(dev1,1,'aux',channel),

