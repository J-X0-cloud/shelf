import { Button } from "@/components/ui/Button";

export default function NotFound() {
  return (
    <section className="phero center">
      <div className="wrap">
        <p className="eyebrow">404</p>
        <h1>Nothing on this shelf.</h1>
        <p className="lede">The page you were looking for has moved or never existed.</p>
        <div className="hero-btns">
          <Button href="/">Back to Shelf</Button>
        </div>
      </div>
    </section>
  );
}
