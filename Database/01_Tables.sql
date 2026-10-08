USE [CUPPO];
GO

-- ===== Log.ErrorLog
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Log].[ErrorLog](
	[ErrorLogID] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[AppModule] [varchar](100) NULL,
	[MethodName] [varchar](100) NULL,
	[ProcedureName] [varchar](100) NOT NULL,
	[ErrorCode] [int] NOT NULL,
	[ErrorMessage] [varchar](max) NOT NULL,
	[InputData] [varchar](max) NULL,
	[ClientIP] [varchar](45) NULL,
	[ExecutionTime] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ErrorLogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [Log].[ErrorLog] ADD  CONSTRAINT [DF_ErrorLog_ExecutionTime]  DEFAULT (sysutcdatetime()) FOR [ExecutionTime]
GO

-- ===== Security.Actions
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Security].[Actions](
	[ActionID] [int] IDENTITY(1,1) NOT NULL,
	[Code] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[Description] [varchar](500) NULL,
	[StatusID] [int] NOT NULL,
	[CreationUserID] [int] NOT NULL,
	[UpdateUserID] [int] NULL,
	[CreationDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NULL,
 CONSTRAINT [PK_Actions] PRIMARY KEY CLUSTERED 
(
	[ActionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Actions_Code] UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [Security].[Actions] ADD  CONSTRAINT [DF_Actions_StatusID]  DEFAULT ((1)) FOR [StatusID]
GO
ALTER TABLE [Security].[Actions] ADD  CONSTRAINT [DF_Actions_CreationDate]  DEFAULT (getdate()) FOR [CreationDate]
GO

-- ===== Security.Modules
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Security].[Modules](
	[ModuleID] [int] IDENTITY(1,1) NOT NULL,
	[Code] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[Description] [varchar](500) NULL,
	[ParentModuleID] [int] NULL,
	[Icon] [varchar](50) NULL,
	[Route] [varchar](100) NULL,
	[DisplayOrder] [int] NOT NULL,
	[StatusID] [int] NOT NULL,
	[CreationUserID] [int] NOT NULL,
	[UpdateUserID] [int] NULL,
	[CreationDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NULL,
 CONSTRAINT [PK_Modules] PRIMARY KEY CLUSTERED 
(
	[ModuleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Modules_Code] UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [Security].[Modules] ADD  CONSTRAINT [DF_Modules_DisplayOrder]  DEFAULT ((0)) FOR [DisplayOrder]
GO
ALTER TABLE [Security].[Modules] ADD  CONSTRAINT [DF_Modules_StatusID]  DEFAULT ((1)) FOR [StatusID]
GO
ALTER TABLE [Security].[Modules] ADD  CONSTRAINT [DF_Modules_CreationDate]  DEFAULT (getdate()) FOR [CreationDate]
GO
ALTER TABLE [Security].[Modules]  WITH CHECK ADD  CONSTRAINT [FK_Modules_ParentModule] FOREIGN KEY([ParentModuleID])
REFERENCES [Security].[Modules] ([ModuleID])
GO
ALTER TABLE [Security].[Modules] CHECK CONSTRAINT [FK_Modules_ParentModule]
GO

-- ===== Security.ModuleActions
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Security].[ModuleActions](
	[ModuleActionID] [int] IDENTITY(1,1) NOT NULL,
	[ModuleID] [int] NOT NULL,
	[ActionID] [int] NOT NULL,
	[StatusID] [int] NOT NULL,
 CONSTRAINT [PK_ModuleActions] PRIMARY KEY CLUSTERED 
(
	[ModuleActionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ModuleActions_Module_Action] UNIQUE NONCLUSTERED 
(
	[ModuleID] ASC,
	[ActionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [Security].[ModuleActions] ADD  CONSTRAINT [DF_ModuleActions_StatusID]  DEFAULT ((1)) FOR [StatusID]
GO
ALTER TABLE [Security].[ModuleActions]  WITH CHECK ADD  CONSTRAINT [FK_ModuleActions_Actions] FOREIGN KEY([ActionID])
REFERENCES [Security].[Actions] ([ActionID])
GO
ALTER TABLE [Security].[ModuleActions] CHECK CONSTRAINT [FK_ModuleActions_Actions]
GO
ALTER TABLE [Security].[ModuleActions]  WITH CHECK ADD  CONSTRAINT [FK_ModuleActions_Modules] FOREIGN KEY([ModuleID])
REFERENCES [Security].[Modules] ([ModuleID])
GO
ALTER TABLE [Security].[ModuleActions] CHECK CONSTRAINT [FK_ModuleActions_Modules]
GO

-- ===== Security.Roles
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Security].[Roles](
	[RoleID] [int] IDENTITY(1,1) NOT NULL,
	[Code] [varchar](20) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[Description] [varchar](250) NULL,
	[StatusID] [int] NOT NULL,
	[CreationUserID] [int] NOT NULL,
	[UpdateUserID] [int] NULL,
	[CreationDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NULL,
 CONSTRAINT [PK_Roles] PRIMARY KEY CLUSTERED 
(
	[RoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Roles_Code] UNIQUE NONCLUSTERED 
(
	[Code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [Security].[Roles] ADD  CONSTRAINT [DF_Roles_StatusID]  DEFAULT ((1)) FOR [StatusID]
GO
ALTER TABLE [Security].[Roles] ADD  CONSTRAINT [DF_Roles_CreationDate]  DEFAULT (getdate()) FOR [CreationDate]
GO

-- ===== Security.RolePermissions
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Security].[RolePermissions](
	[RoleID] [int] NOT NULL,
	[ModuleActionID] [int] NOT NULL,
	[CreationUserID] [int] NOT NULL,
	[CreationDate] [datetime] NOT NULL,
 CONSTRAINT [PK_RolePermissions] PRIMARY KEY CLUSTERED 
(
	[RoleID] ASC,
	[ModuleActionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_RolePermissions_RoleID] ON [Security].[RolePermissions]
(
	[RoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [Security].[RolePermissions] ADD  CONSTRAINT [DF_RolePermissions_CreationDate]  DEFAULT (getdate()) FOR [CreationDate]
GO
ALTER TABLE [Security].[RolePermissions]  WITH CHECK ADD  CONSTRAINT [FK_RolePermissions_ModuleActions] FOREIGN KEY([ModuleActionID])
REFERENCES [Security].[ModuleActions] ([ModuleActionID])
GO
ALTER TABLE [Security].[RolePermissions] CHECK CONSTRAINT [FK_RolePermissions_ModuleActions]
GO
ALTER TABLE [Security].[RolePermissions]  WITH CHECK ADD  CONSTRAINT [FK_RolePermissions_Roles] FOREIGN KEY([RoleID])
REFERENCES [Security].[Roles] ([RoleID])
GO
ALTER TABLE [Security].[RolePermissions] CHECK CONSTRAINT [FK_RolePermissions_Roles]
GO

-- ===== Security.Users
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Security].[Users](
	[UserID] [int] IDENTITY(1,1) NOT NULL,
	[UserLogin] [varchar](50) NOT NULL,
	[Name] [varchar](50) NOT NULL,
	[Mail] [varchar](50) NOT NULL,
	[PasswordHash] [varbinary](256) NOT NULL,
	[PasswordSalt] [varbinary](32) NOT NULL,
	[Blocked] [bit] NOT NULL,
	[FailedLoginAttempts] [int] NOT NULL,
	[StatusID] [int] NOT NULL,
	[CreationUserID] [int] NULL,
	[UpdateUserID] [int] NULL,
	[CreationDate] [datetime] NOT NULL,
	[UpdateDate] [datetime] NULL,
 CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Users_Mail] UNIQUE NONCLUSTERED 
(
	[Mail] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Users_UserLogin] UNIQUE NONCLUSTERED 
(
	[UserLogin] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [Security].[Users] ADD  CONSTRAINT [DF_Users_Blocked]  DEFAULT ((0)) FOR [Blocked]
GO
ALTER TABLE [Security].[Users] ADD  CONSTRAINT [DF_Users_FailedAttempts]  DEFAULT ((0)) FOR [FailedLoginAttempts]
GO
ALTER TABLE [Security].[Users] ADD  CONSTRAINT [DF_Users_StatusID]  DEFAULT ((1)) FOR [StatusID]
GO
ALTER TABLE [Security].[Users] ADD  CONSTRAINT [DF_Users_CreationDate]  DEFAULT (getdate()) FOR [CreationDate]
GO

-- ===== Security.UserRoles
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Security].[UserRoles](
	[UserID] [int] NOT NULL,
	[RoleID] [int] NOT NULL,
	[CreationUserID] [int] NOT NULL,
	[CreationDate] [datetime] NOT NULL,
 CONSTRAINT [PK_UserRoles] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC,
	[RoleID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_UserRoles_UserID] ON [Security].[UserRoles]
(
	[UserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [Security].[UserRoles] ADD  CONSTRAINT [DF_UserRoles_CreationDate]  DEFAULT (getdate()) FOR [CreationDate]
GO
ALTER TABLE [Security].[UserRoles]  WITH CHECK ADD  CONSTRAINT [FK_UserRoles_Roles] FOREIGN KEY([RoleID])
REFERENCES [Security].[Roles] ([RoleID])
GO
ALTER TABLE [Security].[UserRoles] CHECK CONSTRAINT [FK_UserRoles_Roles]
GO
ALTER TABLE [Security].[UserRoles]  WITH CHECK ADD  CONSTRAINT [FK_UserRoles_Users] FOREIGN KEY([UserID])
REFERENCES [Security].[Users] ([UserID])
GO
ALTER TABLE [Security].[UserRoles] CHECK CONSTRAINT [FK_UserRoles_Users]
GO

