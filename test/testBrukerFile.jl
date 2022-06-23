@testset "BrukerFile" begin

@testset "BrukerFile read" begin
    b = BrukerFile( joinpath(datadir, "BrukerFile", "2D_RARE") )
    @test b["ExcPulse1"] == "(1.3125, 3200, 90, Yes, 3, 4200, 0.236151639875348, 0.200434548747244, 0, 50, 0.317196887605166, <\$ExcPulse1Shape>)"
    @test b["PVM_Fov"] == ["27","27"]
    @test b["PVM_FreqDriftYN"] == "Yes"

    @test b["VisuCoreWordType"] == "_16BIT_SGN_INT"
    @test b["VisuFGOrderDesc"][1] == Any[15.0, " <FG_SLICE>", " <>", 0.0, 2.0]
    @test b["VisuCoreDataOffs"] == repeat(["0","0","0"],5)
end

@testset "BrukerFile Reco" begin
b = BrukerFile( joinpath(datadir, "BrukerFile", "2D_RARE") )

acq = RawAcquisitionData(b)
acqData = AcquisitionData(acq)
N = acqData.encodingSize

params = Dict{Symbol, Any}()
params[:reco] = "direct"
params[:reconSize] = (N[1],N[2]) #this should be clear from context

Ireco = reconstruction(acqData, params)
exportImage( joinpath(tmpdir, "brukerCart.png"), abs.(Ireco[:,:,1,1,1]))

# Convert to ISMRMRD file
fout = ISMRMRDFile(joinpath(tmpdir, "brukerfileCart.h5"))
save(fout, acq)

# Reco data stored in BrukerFile
Iloaded = recoData(b)
@test size(Iloaded) == (128, 128, 15)

## Test reconstruction for multi-coil datasets (2D and 3D FLASH)
listBrukFiles = ["2D_FLASH","3D_FLASH"]
listNormValues = [0.02, 0.15]

for i = 1:length(listBrukFiles)
    b = BrukerFile( joinpath(datadir, "BrukerFile", listBrukFiles[i]) )
    raw = RawAcquisitionData(b)
    acq = AcquisitionData(raw)
    params = Dict{Symbol, Any}()
    params[:reco] = "direct"
    if (acq.encodingSize[3]>1)
        params[:reconSize] = (acq.encodingSize[1],acq.encodingSize[2],acq.encodingSize[3]);
    else
        params[:reconSize] = (acq.encodingSize[1],acq.encodingSize[2]);
    end
    Ireco = reconstruction(acq, params);
    @test size(Ireco) == (raw.params["encodedSize"][1], raw.params["encodedSize"][2], raw.params["encodedSize"][3], 1, raw.params["receiverChannels"])

    Isos = sqrt.(sum(abs.(Ireco).^2,dims=5));
    Isos = Isos ./ maximum(Isos);

    I2dseq = recoData(b)
    I2dseq = I2dseq ./ maximum(I2dseq);

    @test norm(vec(I2dseq)-vec(Isos))/norm(vec(I2dseq)) < listNormValues[i]
end

# Reconstruction of 3DUTE
@info "Reconstruction of 3DUTE"
b = BrukerFile( joinpath(datadir, "BrukerFile", "3D_UTE_NR2") )

raw = RawAcquisitionData(b);
acq = AcquisitionData(raw);  # TODO vérification des modifications qui ont étaient effectuée

params = Dict{Symbol, Any}()
params[:reco] = "direct"
if (acq.encodingSize[3]>1)
    params[:reconSize] = (acq.encodingSize[1],acq.encodingSize[2],acq.encodingSize[3]);
else
    params[:reconSize] = (acq.encodingSize[1],acq.encodingSize[2]);
end

Ireco = reconstruction(acq, params);

Isos = sqrt.(sum(abs.(Ireco).^2,dims=5));
Isos = Isos ./ maximum(Isos);
I2dseq = recoData(b)
I2dseq = I2dseq ./ maximum(I2dseq);
# reorient
I2dseq = permutedims(I2dseq,(2,1,3,4))
I2dseq = circshift(I2dseq,(0,0,1,0))

@test MRIReco.norm(vec(I2dseq)-vec(Isos))/MRIReco.norm(vec(I2dseq)) < 0.1
end


end
