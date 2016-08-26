%This is a function to import an encoded file from the FPGA 4piBetaGamma
%acquisition system, and decode the data into a matrix.

function TheData = DecodeData(filename)

EncodedData = load(filename);
EncodedData = uint64(EncodedData);

TheData = zeros(max(size(EncodedData)), 4);

%Get channel 1 data, 1st column
%Not sure why it needs to be 56, as it's actually the 55th bit.
%My guess is that it is due to Matlab's indexing from 1, not 0.
TheData(:,1) = bitget(EncodedData, 56);

%Get channel 2 data, 2nd column
TheData(:,2) = bitget(EncodedData, 57);

%Get timeout data, 4th column
TheData(:,4) = bitget(EncodedData, 58);

%Change EncodedData bitwise to decode the time.
%There's 2 ways to do this, so I'll try both and pick the faster
EncodedData = bitset(EncodedData, 56, 0);
EncodedData = bitset(EncodedData, 57, 0);
EncodedData = bitset(EncodedData, 58, 0);
%Now put the time in the matrix
TheData(:,3) = EncodedData;

%NB: This approach doesn't work in MabLab 2009! 
%The alternative way:
%the statement below gets uint64 that is all 1's except @ bits 56:58
%dummy = bitcmp(uint64(sum(bitset(uint64(0), [56,57,58]))));
%TheData(:,3) = bitand(EncodedData, dummy);
%After testing, the bottleneck is in loading the file loading anyway (duh!)
%but this command is faster (as one might expect).
end
