import java.lang.reflect.*;
import java.nio.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

/** Headless checks against installed game classes; no world or game UI created. */
public class NativeValidation {
    private static int checks;
    private static void check(boolean ok, String message) {
        if (!ok) throw new AssertionError(message);
        checks++;
    }
    public static void main(String[] args) throws Exception {
        Class<?> parser = Class.forName("zombie.scripting.ScriptParser");
        for (String name : args) {
            String source = new String(Files.readAllBytes(Paths.get(name)), StandardCharsets.UTF_8);
            Object block = parser.getMethod("parse", String.class).invoke(null, source);
            List<?> children = (List<?>)block.getClass().getField("children").get(block);
            check(children.size() == (name.endsWith("sandbox-options.txt") ? 5 : 1), "script block count " + name);
            if (name.endsWith("SQSF_Recipes.txt")) {
                Object module = children.get(0);
                List<?> recipes = (List<?>)module.getClass().getField("children").get(module);
                check(recipes.size() == 24, "24 create/refill recipes");
                Class<?> recipeClass = Class.forName("zombie.scripting.entity.components.crafting.CraftRecipe");
                Class<?> moduleClass = Class.forName("zombie.scripting.objects.ScriptModule");
                // Headless fixture for the normal script-loading context.
                Field loadingMod = Class.forName("zombie.scripting.ScriptManager").getDeclaredField("currentLoadFileMod");
                loadingMod.setAccessible(true); loadingMod.set(null, "pz-vanilla");
                Object nativeModule = moduleClass.getConstructor().newInstance();
                moduleClass.getField("name").set(nativeModule, "SQSF");
                for (Object recipeBlock : recipes) {
                    String id = (String)recipeBlock.getClass().getField("id").get(recipeBlock);
                    Object recipe = recipeClass.getConstructor().newInstance();
                    recipeClass.getMethod("setModule", moduleClass).invoke(recipe, nativeModule);
                    recipeClass.getMethod("InitLoadPP", String.class).invoke(recipe, id);
                    recipeClass.getMethod("Load", String.class, recipeBlock.getClass()).invoke(recipe, id, recipeBlock);
                    check("SuQingIrrigation".equals(recipeClass.getMethod("getCategory").invoke(recipe)), "native crafting category " + id);
                    check(((Number)recipeClass.getMethod("getOutputCount").invoke(recipe)).intValue() == 1, "native output count " + id);
                    check(!((Boolean)recipeClass.getMethod("needToBeLearn").invoke(recipe)), "recipe available without magazine " + id);
                }
            }
        }
        Class<?> unsafeClass = Class.forName("sun.misc.Unsafe");
        Field singleton = unsafeClass.getDeclaredField("theUnsafe"); singleton.setAccessible(true);
        Object unsafe = singleton.get(null);
        Class<?> itemClass = Class.forName("zombie.inventory.types.DrainableComboItem");
        // Avoid constructors requiring the game registries; zeroed fields make
        // updateWeight a no-op, exercising the real dose accessors themselves.
        Object item = unsafeClass.getMethod("allocateInstance", Class.class).invoke(unsafe, itemClass);
        Field delta = itemClass.getDeclaredField("useDelta"); delta.setAccessible(true); delta.setFloat(item, 0.125f);
        itemClass.getMethod("setUsedDelta", float.class).invoke(item, 0.00125f);
        check(((Number)itemClass.getMethod("getCurrentUses").invoke(item)).intValue() == 0, "fractional native dose rounds to zero");
        itemClass.getMethod("setCurrentUses", int.class).invoke(item, 7);
        check(((Number)itemClass.getMethod("getCurrentUses").invoke(item)).intValue() == 7, "exact integer use setter");
        check(Math.abs(((Number)itemClass.getMethod("getCurrentUsesFloat").invoke(item)).doubleValue() - 0.875) < 0.00001, "native float represents integer uses");
        for (int capacity : new int[]{50,200}) {
            delta.setFloat(item, 1.0f/capacity);
            check(((Number)itemClass.getMethod("getMaxUses").invoke(item)).intValue() == capacity, "native pack capacity " + capacity);
            itemClass.getMethod("setCurrentUsesFloat", float.class).invoke(item, 1.0f);
            check(((Number)itemClass.getMethod("getCurrentUses").invoke(item)).intValue() == capacity, "native full pack uses " + capacity);
        }
        Class<?> tableClass = Class.forName("se.krka.kahlua.j2se.KahluaTableImpl");
        Object table = tableClass.getConstructor(Map.class).newInstance(new HashMap<Object,Object>());
        Method rawset = tableClass.getMethod("rawset", Object.class, Object.class);
        rawset.invoke(table, "units", Double.valueOf(23456));
        rawset.invoke(table, "kind", "Mildew");
        rawset.invoke(table, "schema", Double.valueOf(1));
        ByteBuffer buffer = ByteBuffer.allocate(1024);
        tableClass.getMethod("save", ByteBuffer.class).invoke(table, buffer);
        buffer.flip();
        Object restored = tableClass.getConstructor(Map.class).newInstance(new HashMap<Object,Object>());
        tableClass.getMethod("load", ByteBuffer.class, int.class).invoke(restored, buffer, 241);
        Method rawget = tableClass.getMethod("rawget", Object.class);
        check(Double.valueOf(23456).equals(rawget.invoke(restored, "units")), "residue units survive native table serialization");
        check("Mildew".equals(rawget.invoke(restored, "kind")), "residue kind survives native table serialization");
        System.out.println("Native validation passed: " + checks + " checks; game UI not launched.");
    }
}
