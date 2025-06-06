{ pkgs, lib, self }:

lib.runTests {
  testMakeUnitFilename = {
    expr = self.systemd.mkUnitFileName "service" "hello-there";
    expected = "hello-there.service";
  };

  testMakeUnitFilenameForDropIns = {
    expr = self.systemd.mkUnitFileName "service" "hello-there/10-this-is-a-dropin-unit";
    expected = "hello-there.service.d/10-this-is-a-dropin-unit.conf";
  };

  testMakeUnitFilenameWithTemplate = {
    expr = self.systemd.mkUnitFileName "service" "service-with-instance@";
    expected = "service-with-instance@.service";
  };

  testMakeUnitFilenameWithTemplateAndDropIn = {
    expr = self.systemd.mkUnitFileName "service" "service-with-instance@/whot-is-this";
    expected = "service-with-instance@.service.d/whot-is-this.conf";
  };

  testMakeUnitFilenameWithTemplateAndDropInAndAnInstance = {
    expr = self.systemd.mkUnitFileName "service" "service-with-instance@world/whats-my-age-again";
    expected = "service-with-instance@world.service.d/whats-my-age-again.conf";
  };

  testSplitUnitFilename = {
    expr = self.systemd.splitUnitFilename "hello-there.service";
    expected = [ "hello-there.service" ];
  };

  # Well, this is supposed to be a naive function.
  testSplitUnitFilenameWithDropIn = {
    expr = self.systemd.splitUnitFilename "hello-there.service.d/10-this-is-a-dropin-unit.conf";
    expected = [ "hello-there.service.d" "10-this-is-a-dropin-unit.conf" ];
  };

  testSplitUnitFilenameWithDropInAndInstance = {
    expr = self.systemd.splitUnitFilename "service-with-instance@world.service.d/whats-my-age-again.conf";
    expected = [ "service-with-instance@world.service.d" "whats-my-age-again.conf" ];
  };

  # This one, too.
  testGetUnitName = {
    expr = self.systemd.getUnitName "hello.service.d/10-override.conf";
    expected = "hello.service.d";
  };

  testGetUnitNameWithTemplate = {
    expr = self.systemd.getUnitName "service-with-instance@world.service";
    expected = "service-with-instance@world.service";
  };

  testGetUnitNameWithTemplateInstanceAndDropIn = {
    expr = self.systemd.getUnitName "service-with-instance@world.service.d/whats-my-age-again.conf";
    expected = "service-with-instance@world.service.d";
  };
}
