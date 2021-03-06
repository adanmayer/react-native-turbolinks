package com.lazaronixon.rnturbolinks.activities;

import android.annotation.SuppressLint;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.support.v7.view.menu.MenuBuilder;
import android.support.v7.widget.Toolbar;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.ImageView;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter;
import com.lazaronixon.rnturbolinks.R;
import com.lazaronixon.rnturbolinks.react.ReactAppCompatActivity;
import com.lazaronixon.rnturbolinks.util.ImageLoader;
import com.lazaronixon.rnturbolinks.util.NavBarStyle;
import com.lazaronixon.rnturbolinks.util.TurbolinksAction;
import com.lazaronixon.rnturbolinks.util.TurbolinksRoute;

import java.util.ArrayList;

import static com.lazaronixon.rnturbolinks.RNTurbolinksModule.INTENT_FROM_TAB;
import static com.lazaronixon.rnturbolinks.RNTurbolinksModule.INTENT_INITIAL;
import static com.lazaronixon.rnturbolinks.util.TurbolinksRoute.ACTION_REPLACE;

public abstract class GenericActivity extends ReactAppCompatActivity {

    private static final String TURBOLINKS_ACTION_PRESS = "turbolinksActionPress";
    private static final String TURBOLINKS_TITLE_PRESS = "turbolinksTitlePress";

    protected Toolbar toolBar;
    protected TurbolinksRoute route;
    protected NavBarStyle navBarStyle;

    public abstract void reloadSession();

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        menu.clear();
        if (route.getActions() == null) return true;
        ArrayList<Bundle> actions = route.getActions();
        for (int i = 0; i < actions.size(); i++) {
            TurbolinksAction action = new TurbolinksAction(actions.get(i));
            MenuItem menuItem = menu.add(Menu.NONE, action.getId(), i, action.getTitle());
            renderActionIcon(menu, menuItem, action.getIcon());
            if (action.getButton()) menuItem.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
        }
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        if (item.getItemId() == android.R.id.home) {
            onBackPressed();
            return false;
        } else {
            getEventEmitter().emit(TURBOLINKS_ACTION_PRESS, item.getItemId());
            return true;
        }
    }

    @Override
    public void onBackPressed() {
        if (isInitial()) {
            moveTaskToBack(true);
        } else {
            super.onBackPressed();
        }
    }

    @Override
    public void finish() {
        super.finish();
        setupTransitionOnFinish();
    }

    public void renderTitle(String title, String subtitle) {
        getSupportActionBar().setTitle(title);
        getSupportActionBar().setSubtitle(subtitle);
    }

    public void setActions(ArrayList<Bundle> actions) {
        route.setActions(actions);
    }

    public void renderComponent(TurbolinksRoute route, int tabIndex) {
    }

    public void reloadVisitable() {
    }

    public void evaluateJavaScript(String script, Promise promise) {
    }

    public void notifyTabItem(String value, int tabIndex) {
    }

    public RCTDeviceEventEmitter getEventEmitter() {
        return getReactInstanceManager().getCurrentReactContext().getJSModule(RCTDeviceEventEmitter.class);
    }

    public boolean isInitial() {
        return getIntent().getBooleanExtra(INTENT_INITIAL, true);
    }

    public boolean isFromTab() {
        return getIntent().getBooleanExtra(INTENT_FROM_TAB, false);
    }

    public void setupTransitionOnEnter() {
        if (isInitial() || route.getAction().equals(ACTION_REPLACE)) {
            overridePendingTransition(R.anim.stay_its, R.anim.stay_its);
        } else if (isFromTab() || route.getModal()) {
            overridePendingTransition(R.anim.slide_up, R.anim.stay_its);
        } else {
            overridePendingTransition(R.anim.slide_in_right, R.anim.slide_out_left);
        }
    }

    protected void renderToolBar() {
        setSupportActionBar(toolBar);
        getSupportActionBar().setDisplayHomeAsUpEnabled(!isInitial());
        getSupportActionBar().setTitle(route.getTitle());
        getSupportActionBar().setSubtitle(route.getSubtitle());
        getSupportActionBar().setIcon(getNavIcon(route.getNavIcon()));
        renderTitleImage(route.getTitleImage());
        setupNavBarStyle(navBarStyle);
        if (route.getNavBarHidden() || route.getModal()) getSupportActionBar().hide();
    }

    protected void handleTitlePress(final String component, final String url, final String path) {
        toolBar.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) {
                WritableMap params = Arguments.createMap();
                params.putString("component", component);
                params.putString("url", url);
                params.putString("path", path);
                getEventEmitter().emit(TURBOLINKS_TITLE_PRESS, params);
            }
        });
    }

    protected void restart() {
        finish();
        startActivity(getIntent());
    }

    protected void setupTransitionOnFinish() {
        if (isInitial()) {
            overridePendingTransition(R.anim.stay_its, R.anim.stay_its);
        } else if (isFromTab() || route.getModal()) {
            overridePendingTransition(R.anim.stay_its, R.anim.slide_down);
        } else {
            overridePendingTransition(R.anim.slide_in_left, R.anim.slide_out_right);
        }
    }

    protected Drawable getNavIcon(Bundle icon) {
        if (icon == null) return null;
        String uri = icon.getString("uri");
        return ImageLoader.loadImage(getApplicationContext(), uri);
    }

    protected void renderTitleImage(Bundle image) {
        if (image == null) return;
        String uri = image.getString("uri");
        Drawable imgDraw = ImageLoader.loadImage(getApplicationContext(), uri);
        ImageView imageView = new ImageView(getApplicationContext());
        imageView.setImageDrawable(imgDraw);

        Toolbar.LayoutParams params = new Toolbar.LayoutParams(imgDraw.getIntrinsicWidth(), imgDraw.getIntrinsicHeight());
        params.gravity = Gravity.CENTER;
        imageView.setLayoutParams(params);
        toolBar.addView(imageView);
    }

    protected void setupNavBarStyle(NavBarStyle style) {
        if (style == null) return;
        if (style.getBarTintColor() != 0) { toolBar.setBackgroundColor(style.getBarTintColor()); }
        if (style.getTitleTextColor() != 0) { toolBar.setTitleTextColor(style.getTitleTextColor()); }
        if (style.getSubtitleTextColor() != 0) { toolBar.setSubtitleTextColor(style.getSubtitleTextColor()); }
        if (style.getMenuIcon() != null) { toolBar.setOverflowIcon(ImageLoader.loadImage(getApplicationContext(), style.getMenuIcon().getString("uri"))); }
    }

    @SuppressLint("RestrictedApi")
    protected void renderActionIcon(Menu menu, MenuItem menuItem, Bundle icon) {
        if (icon == null) return;
        if (menu instanceof MenuBuilder) ((MenuBuilder) menu).setOptionalIconsVisible(true);
        String uri = icon.getString("uri");
        menuItem.setIcon(ImageLoader.loadImage(getApplicationContext(), uri));
    }

}
