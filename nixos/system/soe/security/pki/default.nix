{
  security = {
    pki = {
      certificates = [
        ''
          Caddy root certificate
          =========
          -----BEGIN CERTIFICATE-----
          MIIBpDCCAUqgAwIBAgIRALV7N1hodks42iQG/fAQ+L0wCgYIKoZIzj0EAwIwMDEu
          MCwGA1UEAxMlQ2FkZHkgTG9jYWwgQXV0aG9yaXR5IC0gMjAyNiBFQ0MgUm9vdDAe
          Fw0yNjAxMDMwNDAyMjdaFw0zNTExMTIwNDAyMjdaMDAxLjAsBgNVBAMTJUNhZGR5
          IExvY2FsIEF1dGhvcml0eSAtIDIwMjYgRUNDIFJvb3QwWTATBgcqhkjOPQIBBggq
          hkjOPQMBBwNCAAQqHpP5/LCVffID2/hnpI4CAwQzvzotyzx77s+RuTh3dbnW4KJx
          TRVYiRyvXeUpCbzKyWd2VrYw8fkofYSaMNTAo0UwQzAOBgNVHQ8BAf8EBAMCAQYw
          EgYDVR0TAQH/BAgwBgEB/wIBATAdBgNVHQ4EFgQUpJInrJQUY+04bwjXcJyBXfOx
          /NgwCgYIKoZIzj0EAwIDSAAwRQIgFt5QTxQP9PbBLuy6qcN2+3u0A/5f+Rgy4Yie
          WslxagICIQD0Mf6MhO0QOfELvWIvBZy8+efmkdmQ8A8AGzQGhxfBwA==
          -----END CERTIFICATE-----
          Caddy intermediate certificate
          =========
          -----BEGIN CERTIFICATE-----
          MIIByDCCAW6gAwIBAgIRAM0kDotT4p5jpb3Jxw5uYqkwCgYIKoZIzj0EAwIwMDEu
          MCwGA1UEAxMlQ2FkZHkgTG9jYWwgQXV0aG9yaXR5IC0gMjAyNiBFQ0MgUm9vdDAe
          Fw0yNjAxMDMwNDAyMjdaFw0yNjAxMTAwNDAyMjdaMDMxMTAvBgNVBAMTKENhZGR5
          IExvY2FsIEF1dGhvcml0eSAtIEVDQyBJbnRlcm1lZGlhdGUwWTATBgcqhkjOPQIB
          BggqhkjOPQMBBwNCAAQiozVKCBNoZultMgBa0nbepDvzwGXJaYEFVrdY7AK5zb6q
          jXce4SZOoGOvXJFyGEbMd9k+D7/bI+KCzvaTixqco2YwZDAOBgNVHQ8BAf8EBAMC
          AQYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUrzxQr0QGriJZySTSc1N9
          /CvI0mQwHwYDVR0jBBgwFoAUpJInrJQUY+04bwjXcJyBXfOx/NgwCgYIKoZIzj0E
          AwIDSAAwRQIhAOS+hJ8WjV1aJXxtlak5MV84XmmoGreL9yMZ47Hk1oxaAiBf4Pz6
          HWwzjXAk5IIZjNHR162aucUExMIsKzu7YL/N2A==
          -----END CERTIFICATE-----
          Caddy server certificate
          =========
          -----BEGIN CERTIFICATE-----
          MIIBvDCCAWOgAwIBAgIQERI5oZwCtQUQx5BobnVFSjAKBggqhkjOPQQDAjAzMTEw
          LwYDVQQDEyhDYWRkeSBMb2NhbCBBdXRob3JpdHkgLSBFQ0MgSW50ZXJtZWRpYXRl
          MB4XDTI2MDEwMzA0MDIyN1oXDTI2MDEwMzE2MDIyN1owADBZMBMGByqGSM49AgEG
          CCqGSM49AwEHA0IABKjmku+M0QqtvcBQ2uf932LYQVMrufU9GwIJuaRElT2c57RO
          ym2i5OTj8/mnNPbopWuk6puAqE+YlP22OhX4JSSjgYswgYgwDgYDVR0PAQH/BAQD
          AgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAdBgNVHQ4EFgQUtTlo
          tr4S5AP6yOOkxVCr08CX5wcwHwYDVR0jBBgwFoAUrzxQr0QGriJZySTSc1N9/CvI
          0mQwFwYDVR0RAQH/BA0wC4IJbG9jYWxob3N0MAoGCCqGSM49BAMCA0cAMEQCIDxM
          A26zUbxFCZEiqWYDkVL4Ui7y8NqKPyjDWCz9LeebAiBtWlMyhIjzVwctVBSLu5Wi
          oGfKeDpNWNG9kmVwNzdxhA==
          -----END CERTIFICATE-----
        ''

        # Bingamon Lab Active Directory root CA.
        # Self-signed root, expires 2031-08-11. SHA-256 fingerprint:
        # 76:7C:FF:FC:82:B1:95:C5:0A:0D:47:10:6E:B0:28:D3:D0:4B:D2:6D:1A:1D:D3:5F:AA:EB:B3:2F:84:92:DA:8E
        ''
          Bingamon Lab AD
          =========
          -----BEGIN CERTIFICATE-----
          MIIDUzCCAjugAwIBAgIQIhz0rzsXuIZCz+jkTvcPCTANBgkqhkiG9w0BAQsFADA8
          MRMwEQYKCZImiZPyLGQBGRYDbGFiMRgwFgYKCZImiZPyLGQBGRYIYmluZ2Ftb24x
          CzAJBgNVBAMTAkFEMB4XDTI2MDgxMTAyMjQxMFoXDTMxMDgxMTAyMzQxMFowPDET
          MBEGCgmSJomT8ixkARkWA2xhYjEYMBYGCgmSJomT8ixkARkWCGJpbmdhbW9uMQsw
          CQYDVQQDEwJBRDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKpDQ/vN
          PgkZiuX08Ec+JYtGSvJPkU80hytPdl+xCnOlxnhZBiz7t+c5F7G3lyMn082t91PU
          mjvqQgUb6DD63F7DXmUYKpeH7jtaJoEndHak2tGHgTq9Zhv5EK7RjbrbUVrbycwl
          3Eh1QYuvkiJp3JIDlOXrnU/qBjbUdjoqdm/x3fcvixLQUyW5LDKYhZypLhjRk5lI
          dzYu3mkepnUu7A58TWWe13oPtHizpAkC1nvZgSUtZRGrzDLf3DS4wP2kbaLvjsD6
          1Kjz5qVaCy3RC4g8lDPabP37fh52ivBHdWSTiaVaE2bNymFs7XwRETnRov3PNK15
          /owfeFzzCGweGokCAwEAAaNRME8wCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMB
          Af8wHQYDVR0OBBYEFBjgFc+L20H8fyBhy+lSm2CXMyMgMBAGCSsGAQQBgjcVAQQD
          AgEAMA0GCSqGSIb3DQEBCwUAA4IBAQAkxzOTBdXwJqYI9TuZCUORjTOm3J4oK6Ig
          NLwdqlHDX+x1gBnDcDhWbM2ZZlEC4oM/+A7f0BRy6AuB5kqaK2aFTw4ifGqNVg7q
          nGVrtHrRu8+tMn1wCVncsBV7A051Jk/EFM4EdIUHb3+5z5LXQwcv6rfxKKPGJAs/
          nZkk715qs9IklAFYp6sDxFaFIQ89ThZ+E7zU2aT88GezGQ9312sNJqp+O+V8w9oE
          GkANpc+jU5wSp0CHUiRGyHpLzXa0djCpvKeymmpQs2cBYS8hmtFDmn11DhAUZKT1
          xUIzF1lo624yVOBYUM2Zq5JUP5MqtIwT0UGfmvDGXk27KMKBsGjD
          -----END CERTIFICATE-----
        ''
      ];
    };
  };
}
