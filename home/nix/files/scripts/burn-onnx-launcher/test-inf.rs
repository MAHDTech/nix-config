#[derive(Default)]
struct Foo { a: bool }
fn bar(f: Foo) {}

fn main() {
    let mut opt = Default::default();
    opt.a = true;
    bar(opt);
}
