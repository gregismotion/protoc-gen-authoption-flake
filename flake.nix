{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix.url = "github:tweag/gomod2nix";
    grpc-gateway.url = github:thegergo02/grpc-gateway-flake;
    protoc-gen-validate.url = github:thegergo02/protoc-gen-validate-flake;
    googleapis = {
      flake = false;
      url = github:googleapis/googleapis;
    };
    zitadel-src = {
      type = "git";
      flake = false;
      url = "https://github.com/zitadel/zitadel";
      ref = "refs/tags/v2.0.0-v2-alpha.33";
    };
  };

  outputs =
    { self, nixpkgs, flake-utils, gomod2nix, grpc-gateway, protoc-gen-validate, googleapis, zitadel-src }:
    let
      overlays = [ gomod2nix.overlays.default ];
    in flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system overlays; };
      in
      rec {
        packages = flake-utils.lib.flattenTree
        { 
          protoc-gen-authoption = pkgs.buildGoApplication {
              name = "protoc-gen-authoption";
              src = "${zitadel-src}";
              modRoot = "/build/source/gopath/src/github.com/zitadel/zitadel";
              modules = ./gomod2nix.toml;
              subPackages = [ 
                "internal/protoc/protoc-gen-authoption" 
              ];
              nativeBuildInputs = with pkgs; [
                go-bindata
                protobuf3_18
                protoc-gen-go-grpc
		protoc-gen-go
              ];
              go = pkgs.go_1_17;
              preConfigure = ''
                export GOPATH=$(pwd)/gopath
                export ZITADEL_PATH=$GOPATH/src/github.com/zitadel/zitadel

                export PROTO_PATH=$(pwd)/protoext
                export PROTO_INC_PATH=$PROTO_PATH/include
                export PROTO_ZITADEL_PATH=$PROTO_INC_PATH/zitadel
		
		echo $PROTO_PATH

                mkdir -p $ZITADEL_PATH
                cp -r ${zitadel-src}/* $ZITADEL_PATH/.
                chmod -R +w $ZITADEL_PATH

                mkdir -p $PROTO_INC_PATH/validate
		cp ${protoc-gen-validate.defaultPackage.${system}}/validate.proto $PROTO_INC_PATH/validate
		mkdir -p $PROTO_INC_PATH/protoc-gen-openapiv2/options
		cp ${grpc-gateway.defaultPackage.${system}}/openapiv2/annotations.proto $PROTO_INC_PATH/protoc-gen-openapiv2/options/.
		cp ${grpc-gateway.defaultPackage.${system}}/openapiv2/openapiv2.proto $PROTO_INC_PATH/protoc-gen-openapiv2/options
		mkdir -p $PROTO_INC_PATH/google/api
		cp ${googleapis}/google/api/annotations.proto $PROTO_INC_PATH/google/api/.
		cp ${googleapis}/google/api/http.proto $PROTO_INC_PATH/google/api/.
		cp ${googleapis}/google/api/field_behavior.proto $PROTO_INC_PATH/google/api/.
		cp -r $ZITADEL_PATH/proto/* $PROTO_INC_PATH/.

                mkdir -p /build/go/src
              '';
              preBuild = ''
		pushd ../../../../..
                export GOPATH=$(pwd)/gopath
                export ZITADEL_PATH=$GOPATH/src/github.com/zitadel/zitadel

                export PROTO_PATH=$(pwd)/protoext
                export PROTO_INC_PATH=$PROTO_PATH/include
                export PROTO_ZITADEL_PATH=$PROTO_INC_PATH/zitadel
		
                protoc -I=$PROTO_INC_PATH --go_out $GOPATH/src --go-grpc_out $GOPATH/src $PROTO_ZITADEL_PATH/*.proto

                pushd $ZITADEL_PATH/internal/protoc/protoc-gen-authoption
                go-bindata -pkg main -prefix . -o templates.gen.go templates
                go-bindata -pkg main -o templates.gen.go templates
                protoc -I. -I$GOPATH/src --go-grpc_out=$GOPATH/src authoption/options.proto
                popd
		popd
              '';
          };
        };
        
        defaultPackage = packages.protoc-gen-authoption;

        apps.protoc-gen-authoption = flake-utils.lib.mkApp { name = "protoc-gen-authoption"; drv = packages.protoc-gen-authoption; };
      });
}

