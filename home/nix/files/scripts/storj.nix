{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    storj-uplink
    python3
    python3Packages.boto3
  ];

  home.file = {
    "storj-presigned-url-put" = {
      target = "${config.home.homeDirectory}/.local/bin/storj-presigned-url-put";
      executable = true;

      text = ''
        #!${pkgs.python3}/bin/python3

        import boto3

        ACCESS_KEY = input("Enter your Access Key: ")
        SECRET_KEY = input("Enter your Secret Key: ")
        URL = input("Enter the URL (e.g., https://gateway.storjshare.io): ")
        BUCKET_NAME = input("Enter your case-sensitive Bucket Name: ")
        BUCKET_PATH = input("Enter the path within the bucket: ")

        session = boto3.session.Session()

        s3 = session.client(
            service_name="s3",
            aws_access_key_id=ACCESS_KEY,
            aws_secret_access_key=SECRET_KEY,
            endpoint_url=URL,
        )

        url = s3.generate_presigned_url(
            "put_object",
            Params={"Bucket": BUCKET_NAME, "Key": BUCKET_PATH},
            ExpiresIn=3600,
        )

        print(url)
      '';
    };
  };
}
