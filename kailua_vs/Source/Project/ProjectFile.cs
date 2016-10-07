﻿using System;
using System.Diagnostics;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.VisualStudio.Text;
using Kailua.Util.Extensions;

namespace Kailua
{
    public class ProjectFile : IDisposable
    {
        internal Project project;
        internal Native.Unit unit = Native.Unit.Dummy;
        internal string path;

        internal CancellationTokenSource cts;
        internal Native.Report report;
        internal List<Native.ReportData> reportData;
        private ITextSnapshot sourceSnapshot;
        private string sourceText;
        private Task<Native.Span> sourceSpanTask;
        private Task<Native.TokenStream> tokenStreamTask;
        private Task<Native.ParseTree> parseTreeTask;

        private readonly object syncLock = new object();

        internal ProjectFile(Project project, string path)
        {
            this.project = project;
            this.path = path;

            this.cts = null;
            this.report = null;
            this.reportData = new List<Native.ReportData>();
            this.sourceSnapshot = null;
            this.sourceText = null;
            this.sourceSpanTask = null;
            this.tokenStreamTask = null;
            this.parseTreeTask = null;
        }

        public string Path
        {
            get { return this.path; }
        }

        public Native.Unit Unit
        {
            get { return this.unit; }
        }

        public IEnumerable<Native.ReportData> ReportData
        {
            get
            {
                // they should be read atomically
                List<Native.ReportData> reportData;
                ITextSnapshot sourceSnapshot;
                lock (this.syncLock)
                {
                    reportData = this.reportData;
                    sourceSnapshot = this.sourceSnapshot;
                }

                foreach (var data_ in reportData)
                {
                    var data = data_;
                    data.Snapshot = sourceSnapshot;
                    yield return data;
                }
            }
        }

        // this can be set to null to make it read directly from the filesystem
        public ITextSnapshot SourceSnapshot
        {
            get
            {
                return this.sourceSnapshot;
            }

            set
            {
                if (this.BeforeReset != null)
                {
                    this.BeforeReset();
                }

                lock (this.syncLock)
                {
                    this.resetUnlocked();
                    if (value != null)
                    {
                        this.sourceSnapshot = value;
                        this.sourceText = value.GetText();
                    }
                }
            }
        }

        // this can be set to null to make it read directly from the filesystem
        public SnapshotSpan SourceSnapshotSpan
        {
            set
            {
                if (this.BeforeReset != null)
                {
                    this.BeforeReset();
                }

                lock (this.syncLock)
                {
                    this.resetUnlocked();
                    if (value != null)
                    {
                        this.sourceSnapshot = value.Snapshot;
                        this.sourceText = value.GetText();
                    }
                }
            }
        }

        // this can be set to null to make it read directly from the filesystem
        public string SourceText
        {
            get { return this.sourceText; }

            set
            {
                if (this.BeforeReset != null)
                {
                    this.BeforeReset();
                }

                lock (this.syncLock)
                {
                    this.resetUnlocked();
                    this.sourceText = value;
                }
            }
        }

        public Task<Native.Span> SourceSpanTask
        {
            get
            {
                lock (this.syncLock)
                {
                    this.ensureSourceSpanTaskUnlocked(sync: true);
                    return this.sourceSpanTask;
                }
            }
        }

        public Task<Native.TokenStream> TokenStreamTask
        {
            get
            {
                lock (this.syncLock)
                {
                    this.ensureTokenStreamTaskUnlocked(sync: true);
                    return this.tokenStreamTask;
                }
            }
        }

        public Native.TokenStream TokenStream
        {
            set
            {
                if (value == null)
                {
                    throw new ArgumentNullException("TokenStream");
                }

                if (this.BeforeReset != null)
                {
                    this.BeforeReset();
                }

                lock (this.syncLock)
                {
                    this.resetUnlocked();
                    this.tokenStreamTask = Task.FromResult(value);
                }
            }
        }

        public Task<Native.ParseTree> ParseTreeTask
        {
            get
            {
                lock (this.syncLock)
                {
                    this.ensureParseTreeTaskUnlocked(sync: false);
                    return this.parseTreeTask;
                }
            }
        }

        public Native.ParseTree ParseTree
        {
            set
            {
                if (value == null)
                {
                    throw new ArgumentNullException("ParseTree");
                }

                if (this.BeforeReset != null)
                {
                    this.BeforeReset();
                }

                lock (this.syncLock)
                {
                    this.resetUnlocked();
                    this.parseTreeTask = Task.FromResult(value);
                }
            }
        }

        public event ResetHandler BeforeReset;

        public delegate void ResetHandler();

        private void resetUnlocked()
        {
            if (this.cts != null)
            {
                this.cts.Cancel();
                this.cts.Dispose();
                this.cts = null;
            }

            if (this.report != null)
            {
                this.report.Dispose();
                this.report = null;
            }
            this.reportData.Clear();

            this.sourceSnapshot = null;
            this.sourceText = null;
            this.sourceSpanTask = null;
            this.tokenStreamTask = null;
            this.parseTreeTask = null;
        }

        private void ensureReportUnlocked()
        {
            if (this.report != null)
            {
                return;
            }

            this.report = new Native.Report();

            Debug.Assert(this.cts == null);
            this.cts = new CancellationTokenSource();
        }

        private void ensureSourceSpanTaskUnlocked(bool sync)
        {
            if (this.sourceSpanTask != null)
            {
                return;
            }

            this.ensureReportUnlocked();
            
            var sourceText = this.sourceText;
            Func<Native.Span> job = () =>
            {
                var source = this.project.Source;
                Native.Span span;
                if (this.unit.IsValid)
                {
                    if (sourceText == null)
                    {
                        span = source.ReplaceByFile(this.unit, path);
                    }
                    else
                    {
                        span = source.ReplaceByString(this.unit, this.path, sourceText);
                    }
                }
                else
                {
                    if (sourceText == null)
                    {
                        span = source.AddFile(this.path);
                    }
                    else
                    {
                        span = source.AddString(this.path, sourceText);
                    }

                    this.unit = span.Unit; // only used in this task, so no synchronization required
                    Debug.Assert(this.unit.IsValid);
                    Trace.Assert(this.project.units.TryAdd(this.unit, this));
                }

                return span;
            };

            if (sync)
            {
                this.sourceSpanTask = job.CreateSyncTask();
            }
            else
            {
                this.sourceSpanTask = Task.Factory.StartNew(job, this.cts.Token, TaskCreationOptions.None, TaskScheduler.Default);
            }
        }

        private void ensureTokenStreamTaskUnlocked(bool sync)
        {
            if (this.tokenStreamTask != null)
            {
                return;
            }

            this.ensureSourceSpanTaskUnlocked(sync);

            var report = this.report;
            var reportData = this.reportData;
            Func<Task<Native.Span>, Native.TokenStream> job = task =>
            {
                try
                {
                    var sourceSpan = task.Result;
                    try
                    {
                        return new Native.TokenStream(this.project.Source, sourceSpan, report);
                    }
                    catch (Exception e)
                    {
                        Log.Write("failed to tokenize {0}: {1}", this.path, e);
                        throw;
                    }
                }
                finally
                {
                    // may continue to return reports even on error
                    foreach (var data in report)
                    {
                        reportData.Add(data);
                    }
                }
            };

            if (sync)
            {
                this.tokenStreamTask = job.CreateSyncTask(this.sourceSpanTask);
            }
            else
            {
                this.tokenStreamTask = this.sourceSpanTask.ContinueWith(job, this.cts.Token, TaskContinuationOptions.None, TaskScheduler.Default);
            }
        }

        private void ensureParseTreeTaskUnlocked(bool sync)
        {
            if (this.parseTreeTask != null)
            {
                return;
            }

            this.ensureTokenStreamTaskUnlocked(sync);

            var report = this.report;
            var reportData = this.reportData;
            Func<Task<Native.TokenStream>, Native.ParseTree> job = task =>
            {
                try
                {
                    var stream = task.Result;
                    try
                    {
                        return new Native.ParseTree(stream, report);
                    }
                    catch (Exception e)
                    {
                        Log.Write("failed to parse {0}: {1}", this.path, e);
                        throw;
                    }
                }
                finally
                {
                    // may continue to return reports even on error
                    foreach (var data in report)
                    {
                        reportData.Add(data);
                    }
                }
            };

            if (sync)
            {
                this.parseTreeTask = job.CreateSyncTask(this.tokenStreamTask);
            }
            else
            {
                this.parseTreeTask = this.tokenStreamTask.ContinueWith(job, this.cts.Token, TaskContinuationOptions.None, TaskScheduler.Default);
            }
        }

        public void Dispose()
        {
            lock (this.syncLock)
            {
                this.resetUnlocked();
            }

            if (this.unit.IsValid)
            {
                ProjectFile projectFile;
                Trace.Assert(this.project.units.TryRemove(this.unit, out projectFile));
                Debug.Assert(projectFile == this);
            }
        }
    }
}