export function GettingStarted({ steps }: { steps: { title: string; body: string }[] }) {
  return (
    <div>
      <h2 className="h3">Getting started</h2>
      <ol className="steps">
        {steps.map((step, i) => (
          <li key={step.title}>
            <span className="n">{i + 1}</span>
            <div>
              <h3>{step.title}</h3>
              <p>{step.body}</p>
            </div>
          </li>
        ))}
      </ol>
    </div>
  );
}
