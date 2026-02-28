package com.comedymoon.fpvdrone;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import static net.minecraft.server.command.CommandManager.*;
import com.mojang.brigadier.arguments.BoolArgumentType;
import com.mojang.brigadier.arguments.FloatArgumentType;
public class FPVMod implements ModInitializer {
    @Override
    public void onInitialize() {
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            dispatcher.register(literal("fpv")
                .requires(source -> source.hasPermissionLevel(2))
                .then(literal("toggle")
                    .then(argument("state", BoolArgumentType.bool())
                        .executes(context -> {
                            FPVState.isActive = BoolArgumentType.getBool(context, "state");
                            return 1;
                        })
                    )
                )
                .then(literal("signal")
                    .then(argument("strength", FloatArgumentType.floatArg(0.0f, 1.0f))
                        .executes(context -> {
                            FPVState.targetSignalStrength = FloatArgumentType.getFloat(context, "strength");
                            return 1;
                        })
                    )
                )
            );
        });
    }
}
