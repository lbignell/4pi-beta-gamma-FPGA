%This function is a simple TAC analysis program.
%I'm NOT certain if it is equivalent to the hardware TAC (it's probably
%not), but it should give an accurate time spectrum.

%Inputs:
%Data = 4-column wide, decoded data matrix.
%startchannel = the channel that starts the TAC
%Note that if there is no clear 'start' channel (TAC spectrum spreads out
%either side of t=0, you can run twice, alternating the start channel).
function spectrum = TAC(Data, startchannel)

%Spectrum is 100000 bins wide, with 1 ns wide bins, so 100 uSec of range.
spectrum = zeros(size(1:100000));
Ch1 = 0;
Ch2 = 0;
Time = 0;
Ticklength = 10;%nanoseconds
hazStarted = false;
isStart = false;
Delay = 0;
StartTime = 0;
ThisBin = 0;

for i = 1:max(size(Data))
    %read in next line.
    Ch1 = Data(i,1);
    Ch2 = Data(i,2);
    Time = Data(i,3)*Ticklength;
    %disp(' ');
    %disp(sprintf('Ch1 = %i, Ch2 = %i, time (ns) = %d', Ch1, Ch2, Time));
    
    if Data(i,startchannel)
        isStart = true;
        %disp('start signal');
    else
        isStart = false;
        %disp('stop signal');
    end
    
    if hazStarted
        %Start signal has already been received.
        %disp('hazStarted = true');
        if ~(isStart)
		 %Not the starting channel, so log the TAC event.
            %disp('TAC event, logging...');
            Delay = Time - StartTime;
            %disp(sprintf('Delay = %d', Delay));
            %Delay is in ns, and so are the bins, so the bin is just the
            %next lowest integer.
            ThisBin = floor(Delay);
            if ThisBin<100000
                spectrum(ThisBin) = spectrum(ThisBin)+1;
            else
                spectrum(100000) = spectrum(100000) + 1;
            end
            hazStarted = false;
        else
		 %The starting channel is firing again. Look for a new coincidence!
            %disp('New Start');
            %New start signal received.
            StartTime = Data(i,3);
        end
    else
        if ~(isStart)
            %disp('Stop followed by stop');
            %Stop signal following with no start, do nothing.
        else
            %disp('Brand new start signal!!');
            %Start signal.
            StartTime = Data(i,3);
            hazStarted = true;
        end
    end
end

figure;
plot(spectrum);
disp(sprintf('Number of counts in TAC spectrum = %i',sum(spectrum)));

end