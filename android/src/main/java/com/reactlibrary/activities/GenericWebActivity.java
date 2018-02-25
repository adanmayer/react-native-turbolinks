package com.reactlibrary.activities;

import com.basecamp.turbolinks.TurbolinksAdapter;
import com.facebook.react.ReactInstanceManager;
import com.reactlibrary.util.TurbolinksRoute;
import com.reactlibrary.util.TurbolinksViewGroup;

public interface GenericWebActivity extends GenericActivity, TurbolinksAdapter {

    TurbolinksViewGroup getTurbolinksViewGroup();

    String getMessageHandler();

    String getUserAgent();

    void renderComponent(TurbolinksRoute tRoute, int tabIndex);

    void reload();

}
