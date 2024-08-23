import Image from "next/image";
import Link from "next/link";

export function Brand() {
  return (
    <Link className="brand" href="/" aria-label="Shelf home">
      <Image src="/shelf-icon.svg" alt="" width={30} height={30} priority />
      <span>Shelf</span>
    </Link>
  );
}
