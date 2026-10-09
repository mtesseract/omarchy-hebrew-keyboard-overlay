import Quickshell.Io

// A Process that reports when its program can't be run at all, for example
// because it isn't installed. Process itself only stops without having started.
Process {
  id: process

  signal failedToStart()

  property bool hasStarted: false

  onStarted: process.hasStarted = true
  onRunningChanged: {
    if (process.running) return
    if (!process.hasStarted) process.failedToStart()
    process.hasStarted = false
  }
}
