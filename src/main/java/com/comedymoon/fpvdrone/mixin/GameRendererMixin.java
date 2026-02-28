package com.comedymoon.fpvdrone.mixin;
import com.comedymoon.fpvdrone.FPVState;
import net.minecraft.client.render.GameRenderer;
import net.minecraft.client.render.RenderTickCounter;
import net.minecraft.util.Identifier;
import net.minecraft.client.gl.PostEffectProcessor;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
@Mixin(GameRenderer.class)
public abstract class GameRendererMixin {
    @Shadow protected abstract void loadPostProcessor(Identifier id);
    @Shadow protected abstract void disablePostProcessor();
    @Shadow private PostEffectProcessor postProcessor;
    private boolean wasActiveLastFrame = false;
    private long lastFrameTime = System.currentTimeMillis();
    private float glitchAccum = 0.0f;
    private float glitchDecay = 0.0f;
    @Inject(method = "render", at = @At("HEAD"))
    private void injectFPVShader(RenderTickCounter tickCounter, boolean tick, CallbackInfo ci) {
        Identifier shaderId = Identifier.of("fpvdrone", "shaders/post/fpv.json");
        long now = System.currentTimeMillis();
        float dt = Math.min((now - lastFrameTime) / 1000.0f, 0.1f); 
        lastFrameTime = now;
        float current = FPVState.signalStrength;
        float target  = FPVState.targetSignalStrength;
        float diff    = target - current;
        float speed = FPVState.LERP_SPEED + Math.abs(diff) * 1.2f;
        float newSignal = current + diff * Math.min(speed * dt, 1.0f);
        if (Math.abs(diff) > 0.01f) {
            if (Math.random() < 0.15 * dt * 60.0) {
                glitchAccum = (float)(Math.random() * Math.abs(diff) * 0.35f);
                glitchDecay = (float)(0.08 + Math.random() * 0.12); 
            }
        }
        glitchAccum = Math.max(0, glitchAccum - glitchDecay * dt * 10f);
        float displaySignal = newSignal - glitchAccum;
        displaySignal = Math.max(0.0f, Math.min(1.0f, displaySignal));
        FPVState.signalStrength = newSignal; 
        if (FPVState.isActive) {
            if (!wasActiveLastFrame) {
                this.loadPostProcessor(shaderId);
                wasActiveLastFrame = true;
            }
            if (this.postProcessor != null) {
                this.postProcessor.setUniforms("SignalStrength", displaySignal);
                this.postProcessor.setUniforms("Time", (float)(System.currentTimeMillis() % 1000000) / 1000.0f);
            }
        } else if (wasActiveLastFrame) {
            this.disablePostProcessor();
            wasActiveLastFrame = false;
        }
    }
}
