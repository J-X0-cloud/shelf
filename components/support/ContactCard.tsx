import { Button } from "@/components/ui/Button";
import { Icon } from "@/components/ui/Icon";
import { supportEmail } from "@/lib/data/site";

export function ContactCard() {
  return (
    <aside className="contact">
      <span className="f3-i">
        <Icon name="mail" size={22} />
      </span>
      <h3>Talk to us</h3>
      <p>Bug reports, feature ideas and license questions all go to the same inbox.</p>
      <Button href={`mailto:${supportEmail}`}>Email {supportEmail}</Button>
      <p className="fine">
        Tip: Settings → General → Copy diagnostics adds a redacted report with no file names or paths.
      </p>
    </aside>
  );
}
