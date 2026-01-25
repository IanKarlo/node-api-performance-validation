const std = @import("std");

pub fn build(b: *std.Build) void {
    // 1. Opções padrão de target e otimização
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 2. Criação da Biblioteca Compartilhada (.so/.dll/.dylib)
    // No Zig 0.15, usamos 'addLibrary' definindo a 'linkage' como .dynamic
    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "addon",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"), // 'b.path' é obrigatório agora
            .target = target,
            .optimize = optimize,
        }),
    });

    // 3. Linkar LibC (Necessário para headers C como node_api.h)
    lib.linkLibC();

    // 4. Adicionar o diretório de includes
    // Agora preferimos adicionar ao 'root_module' diretamente
    lib.root_module.addIncludePath(b.path("include"));

    // 5. Configurações do Linker para N-API
    // Permitimos símbolos indefinidos (undefined symbols) porque as funções
    // do Node (napi_*) só existem quando o addon é carregado pelo Node.js.
    lib.root_module.strip = false;
    lib.linker_allow_shlib_undefined = true;

    // 6. Instalação (move o arquivo final para zig-out/lib/)
    // b.installArtifact(lib);
    // Instala com a extensão .node (necessário para Node.js)
    const install_step = b.addInstallFile(lib.getEmittedBin(), "lib/addon.node");
    b.getInstallStep().dependOn(&install_step.step);
}
