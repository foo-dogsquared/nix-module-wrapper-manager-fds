{
  pkgs,
  lib,
  self,
}:

lib.runTests {
  testsUtilsGetBin = {
    expr = self.utils.getBin [
      ../../lib
      ../../modules
    ];
    expected = [
      (lib.getBin ../../lib)
      (lib.getBin ../../modules)
    ];
  };

  testsUtilsGetLibexec = {
    expr = self.utils.getLibexec [
      ../../lib
      ../../modules
    ];
    expected = [
      "${../../lib}/libexec"
      "${../../modules}/libexec"
    ];
  };

  testsUtilsGetXdgConfigDirs = {
    expr = self.utils.getXdgConfigDirs [
      ../../lib
      ../../modules
    ];
    expected = [
      "${../../lib}/etc/xdg"
      "${../../modules}/etc/xdg"
    ];
  };

  testsUtilsGetXdgDataDirs = {
    expr = self.utils.getXdgDataDirs [
      ../../lib
      ../../modules
    ];
    expected = [
      "${../../lib}/share"
      "${../../modules}/share"
    ];
  };

  testsUtilsSplitStringOnce = {
    expr = self.utils.splitStringOnce "/" "foodogsquared/hello/there";
    expected = [ "foodogsquared" "hello/there" ];
  };

  testsUtilsSplitStringOnce2 = {
    expr = self.utils.splitStringOnce "/" "foo@.service/10-hello.conf";
    expected = [ "foo@.service" "10-hello.conf" ];
  };

  testsUtilsSplitStringOnce3 = {
    expr = self.utils.splitStringOnce ":" "there/is/no/colon/here";
    expected = [ "there/is/no/colon/here" ];
  };
}
