{ _ }:
{
  # pd-mapper: Protection Domain Mapper for Qualcomm DSPs
  # The Vinarskis kernel you are using often includes these as built-in
  # or managed via kernel worker threads in newer versions.
  boot.kernelModules = [ "qcom_pd_mapper" ];
}
