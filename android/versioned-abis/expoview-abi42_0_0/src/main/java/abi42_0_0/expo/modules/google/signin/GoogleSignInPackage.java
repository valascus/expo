package abi42_0_0.expo.modules.google.signin;

import android.content.Context;

import java.util.Collections;
import java.util.List;

import abi42_0_0.org.unimodules.core.ExportedModule;
import abi42_0_0.org.unimodules.core.BasePackage;

public class GoogleSignInPackage extends BasePackage {
    @Override
    public List<ExportedModule> createExportedModules(Context context) {
        return Collections.singletonList((ExportedModule) new GoogleSignInModule(context));
    }
}
