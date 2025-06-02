{ pkgs, lib, self }:

lib.runTests {
  testSystemdINIBasic = {
    expr = self.generators.toSystemdINI {
      greetings.hello = "WORLD";
    };
    expected = ''
      [greetings]
      hello=WORLD
    '';
  };

  testSystemdINIBasicWithMultipleSections = {
    expr = self.generators.toSystemdINI {
      Unit = {
        Description = [ "man:systemctl" "https://systemd.io" ];
      };

      Service.ExecStart = "systemctl --help";
    };
    expected = ''
      [Service]
      ExecStart=systemctl --help

      [Unit]
      Description=man:systemctl
      Description=https://systemd.io
    '';
  };

  testSystemdINISectionsWithMultipleSameName = {
    expr = self.generators.toSystemdINI {
      Network = [
        {
          Match = "enps30";
          Type = "ether";
        }
        { Match = "ens0"; }
      ];
    };
    expected = ''
      [Network]
      Match=enps30
      Type=ether

      [Network]
      Match=ens0
    '';
  };

  testsSystemdINISectionsWithMultipleSections = {
    expr = self.generators.toSystemdINI {
      Network = [
        { Match = "ens0"; }
        { Match = "enps30"; }
      ];

      Unit.Description = "WHAAAAT";
    };
    expected = ''
      [Network]
      Match=ens0

      [Network]
      Match=enps30

      [Unit]
      Description=WHAAAAT
    '';
  };
}
