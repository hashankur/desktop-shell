fn main() {
    let config = slint_build::CompilerConfiguration::new().with_style("cosmic-dark".into());
    slint_build::compile_with_config("ui/app-window.slint", config).expect("Slint build failed");
}
