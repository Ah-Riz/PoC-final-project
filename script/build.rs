use sp1_build::{build_program_with_args, BuildArgs};

fn main() {
    // Build the ZK program
    build_program_with_args(
        "../zk-program",
        BuildArgs::default(),
    );
}
