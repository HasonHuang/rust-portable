fn main() {
    println!("Hello from the portable Rust environment!");
    println!("Toolchain: {} / {}", std::env::consts::OS, std::env::consts::ARCH);
}
